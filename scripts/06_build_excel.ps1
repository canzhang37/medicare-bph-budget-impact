# BIM workbook via Excel COM + sensitivity runs

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$fam = Import-Csv "$root\results\bim_family_inputs.csv"
$sc = Get-Content "$root\results\bim_scalars.json" -Raw | ConvertFrom-Json
$out = "$root\results\bph_budget_impact_model.xlsx"

$xl = New-Object -ComObject Excel.Application
$xl.Visible = $false
$xl.DisplayAlerts = $false
try {
$wb = $xl.Workbooks.Add()
while ($wb.Worksheets.Count -lt 4) { [void]$wb.Worksheets.Add([Type]::Missing, $wb.Worksheets.Item($wb.Worksheets.Count)) }
$inp = $wb.Worksheets.Item(1); $inp.Name = "Inputs"
$mod = $wb.Worksheets.Item(2); $mod.Name = "Model"
$sen = $wb.Worksheets.Item(3); $sen.Name = "Sensitivity"
$src = $wb.Worksheets.Item(4); $src.Name = "Sources"

# COM wants [double], not a PSObject
function Put($ws, $addr, $v) { if ($v -is [string]) { $ws.Range($addr).Value2 = $v } else { $ws.Range($addr).Value2 = [double]$v } }
function F($ws, $addr, $f) { $ws.Range($addr).Formula = $f }

# ---- Inputs
Put $inp "A1" "BPH procedures in Medicare FFS: budget impact of a new office-based therapy (inputs)"
$labels = @(
  @("A3", "First procedures per year (2024, corrected)", "B3", [double]$sc.n),
  @("A4", "New-therapy payment per procedure (office urethral lift, CY2026)", "B4", [double]$sc.c_new),
  @("A5", "New-therapy payment multiplier", "B5", 1),
  @("A6", "New-therapy annual surgical retreatment rate", "B6", [double]$sc.r_new),
  @("A7", "Cost of one retreatment (average TURP)", "B7", [double]$sc.c_ret),
  @("A8", "Annual volume growth", "B8", 0),
  @("A9", "Uptake multiplier", "B9", 1),
  @("A10", "Displace minimally invasive families only (1 = yes, 0 = all families)", "B10", 0))
foreach ($l in $labels) { Put $inp $l[0] $l[1]; Put $inp $l[2] $l[3] }
Put $inp "A12" "Year"; Put $inp "A13" "Base uptake of new therapy"; Put $inp "A14" "Uptake used"
$cols = @("B", "C", "D", "E", "F")
for ($i = 0; $i -lt 5; $i++) {
  Put $inp "$($cols[$i])12" ($i + 1)
  Put $inp "$($cols[$i])13" ([double]$sc.uptake[$i])
  F $inp "$($cols[$i])14" "=$($cols[$i])13*`$B`$9"
}
$hdr = @("Family", "Share of first procedures", "Index cost (2026 allowed)", "Annual retreatment rate",
         "Minimally invasive (1/0)", "Displacement weight", "Displacement share", "Retreatment source")
for ($j = 0; $j -lt $hdr.Count; $j++) { $inp.Cells.Item(16, $j + 1).Value2 = $hdr[$j] }
$r0 = 17; $r1 = $r0 + $fam.Count - 1
$k = $r0
foreach ($f in $fam) {
  $inp.Cells.Item($k, 1).Value2 = $f.family
  $inp.Cells.Item($k, 2).Value2 = [double]$f.share
  $inp.Cells.Item($k, 3).Value2 = [double]$f.cost
  $inp.Cells.Item($k, 4).Value2 = [double]$f.retreat
  $inp.Cells.Item($k, 5).Value2 = [double]$f.mist
  $inp.Cells.Item($k, 6).Formula = "=IF(`$B`$10=1,B$k*E$k,B$k)"
  $inp.Cells.Item($k, 7).Formula = "=F$k/SUM(`$F`$$($r0):`$F`$$($r1))"
  $inp.Cells.Item($k, 8).Value2 = $f.retreat_source
  $k++
}
$share = "Inputs!`$B`$$($r0):`$B`$$($r1)"; $cost = "Inputs!`$C`$$($r0):`$C`$$($r1)"
$rate = "Inputs!`$D`$$($r0):`$D`$$($r1)"; $disp = "Inputs!`$G`$$($r0):`$G`$$($r1)"

# ---- Model (years B-F, total G)
Put $mod "A1" "Budget impact model (all cells are formulas on the Inputs sheet)"
$rows = @("Year", "First procedures", "New-therapy uptake", "Index cost per patient, current world",
          "Index cost per patient, new world", "Retreatment rate, current world", "Retreatment rate, new world",
          "Index procedures, current world", "Retreatments, current world", "Total spending, current world",
          "Index procedures, new world", "Retreatments, new world", "Total spending, new world",
          "Net budget impact", "New-therapy patients")
for ($j = 0; $j -lt $rows.Count; $j++) { $mod.Cells.Item($j + 2, 1).Value2 = $rows[$j] }
for ($i = 0; $i -lt 5; $i++) {
  $c = $cols[$i]
  F $mod "${c}2" "=Inputs!${c}12"
  F $mod "${c}3" "=Inputs!`$B`$3*(1+Inputs!`$B`$8)^(${c}2-1)"
  F $mod "${c}4" "=Inputs!${c}14"
  F $mod "${c}5" "=SUMPRODUCT($share,$cost)"
  F $mod "${c}6" "=${c}5-${c}4*SUMPRODUCT($disp,$cost)+${c}4*Inputs!`$B`$4*Inputs!`$B`$5"
  F $mod "${c}7" "=SUMPRODUCT($share,$rate)"
  F $mod "${c}8" "=${c}7-${c}4*SUMPRODUCT($disp,$rate)+${c}4*Inputs!`$B`$6"
  F $mod "${c}9" "=${c}3*${c}5"
  F $mod "${c}12" "=${c}3*${c}6"
  if ($i -eq 0) { F $mod "B10" "=0"; F $mod "B13" "=0" }
  else {
    $p = $cols[$i - 1]
    F $mod "${c}10" "=Inputs!`$B`$7*SUMPRODUCT(`$B`$3:${p}3,`$B`$7:${p}7)"
    F $mod "${c}13" "=Inputs!`$B`$7*SUMPRODUCT(`$B`$3:${p}3,`$B`$8:${p}8)"
  }
  F $mod "${c}11" "=${c}9+${c}10"
  F $mod "${c}14" "=${c}12+${c}13"
  F $mod "${c}15" "=${c}14-${c}11"
  F $mod "${c}16" "=${c}3*${c}4"
}
Put $mod "G2" "5-year total"
foreach ($r in 3, 9, 10, 11, 12, 13, 14, 15, 16) { F $mod "G$r" "=SUM(B${r}:F${r})" }
Put $mod "A18" "Net budget impact per new-therapy patient"; F $mod "B18" "=G15/G16"

# ---- sensitivity cases, then base restored
$fr = $fam | ForEach-Object { [double]$_.retreat }
$cases = @(
  @{case = "base"},
  @{case = "uptake x0.5"; B9 = 0.5}, @{case = "uptake x1.5"; B9 = 1.5},
  @{case = "new-therapy payment -30%"; B5 = 0.7}, @{case = "new-therapy payment +30%"; B5 = 1.3},
  @{case = "new-therapy retreatment lowest"; B6 = ($fr | Measure-Object -Minimum).Minimum},
  @{case = "new-therapy retreatment highest"; B6 = ($fr | Measure-Object -Maximum).Maximum},
  @{case = "displaces minimally invasive only"; B10 = 1},
  @{case = "volume trend 2019-2024"; B8 = [double]$sc.growth_trend})
$base = @{B5 = 1; B6 = [double]$sc.r_new; B8 = 0; B9 = 1; B10 = 0}
$res = @()
Put $sen "A1" "One-way sensitivity analysis (values computed by this workbook's formulas with the listed input changed)"
Put $sen "A3" "Case"; Put $sen "B3" "5-year net budget impact"; Put $sen "C3" "Per new-therapy patient"
$row = 4
foreach ($cs in $cases) {
  foreach ($key in $base.Keys) { $inp.Range($key).Value2 = [double]$base[$key] }
  foreach ($key in $cs.Keys) { if ($key -ne "case") { $inp.Range($key).Value2 = [double]$cs[$key] } }
  $xl.CalculateFull()
  for ($i = 0; $i -lt 5; $i++) {
    $c = $cols[$i]
    $res += [pscustomobject]@{case = $cs.case; year = $i + 1;
      total_current = $mod.Range("${c}11").Value2; total_new = $mod.Range("${c}14").Value2;
      net_impact = $mod.Range("${c}15").Value2; new_therapy_patients = $mod.Range("${c}16").Value2}
  }
  Put $sen "A$row" $cs.case; Put $sen "B$row" $mod.Range("G15").Value2; Put $sen "C$row" $mod.Range("B18").Value2
  $row++
}
foreach ($key in $base.Keys) { $inp.Range($key).Value2 = [double]$base[$key] }
$xl.CalculateFull()
$res | Export-Csv "$root\results\bim_excel_by_year.csv" -NoTypeInformation -Encoding UTF8

# ---- sources and assumptions
$notes = @(
  "Volumes: CMS Medicare Physician & Other Practitioners by Geography and Service 2024 (beneficiary-day services), ASC facility rows removed using the by Provider and Service file; HOPD services from Medicare Outpatient Hospitals by Geography and Service; urethral lift facility claims billed as C9739/C9740.",
  "Payments: CY2026 Physician Fee Schedule (RVU26D, conversion factor 33.4009) for professional fees; 2024 observed HOPD and ASC facility allowed amounts; FY2027 IPPS MS-DRG 714 and 708 base payments (operating 6,848.00 plus capital 539.95 per unit of weight).",
  "Inpatient-or-other cases are paid as inpatient where an inpatient rate exists, otherwise as HOPD.",
  "Retreatment: cumulative surgical retreatment from published 5-year studies (literature sheet in the repository) spread evenly over follow-up; families without a study use the TURP rate; each retreatment is paid as an average TURP.",
  "Retreatments of patients treated before year 1 are the same in both worlds and are left out.",
  "New therapy: hypothetical office-based therapy paid like an office urethral lift, retreatment like water vapor therapy, uptake 2-10% of first procedures over 5 years, taken from the other families in proportion to their shares.",
  "Perspective: Medicare fee-for-service allowed amounts (program payment plus beneficiary cost sharing), undiscounted, 2026 payment rates.")
for ($j = 0; $j -lt $notes.Count; $j++) { $src.Cells.Item($j + 1, 1).Value2 = $notes[$j] }

# ---- formats
$inp.Range("B3:B4").NumberFormat = "#,##0"; $inp.Range("B7").NumberFormat = "`$#,##0"
$inp.Range("B6,B8,B13:F14").NumberFormat = "0.0%"; $inp.Range("B4").NumberFormat = "`$#,##0"
$inp.Range("B$($r0):B$($r1),D$($r0):D$($r1),G$($r0):G$($r1)").NumberFormat = "0.0%"
$inp.Range("C$($r0):C$($r1)").NumberFormat = "`$#,##0"
$mod.Range("B3:G3,B16:G16").NumberFormat = "#,##0"; $mod.Range("B4:F4,B7:F8").NumberFormat = "0.00%"
$mod.Range("B5:F6,B9:G15,B18").NumberFormat = "`$#,##0"
$sen.Range("B4:C20").NumberFormat = "`$#,##0"
foreach ($ws in $inp, $mod, $sen) { $ws.Range("A1").Font.Bold = $true; [void]$ws.Columns.AutoFit() }
$src.Columns.Item(1).ColumnWidth = 140

$wb.RemoveDocumentInformation(99)  # xlRDIAll: author, paths, printer
$wb.SaveAs($out, 51)
$wb.Close($false)
} finally {
  $xl.Quit()
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl)
}

# drop created/modified stamps from core.xml
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($out, "Update")
$e = $zip.GetEntry("docProps/core.xml")
$rd = New-Object System.IO.StreamReader($e.Open()); $xml = $rd.ReadToEnd(); $rd.Close()
$xml = $xml -replace '<dcterms:(created|modified)[^>]*>[^<]*</dcterms:(created|modified)>', ''
$e.Delete()
$n = $zip.CreateEntry("docProps/core.xml")
$n.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)  # as Excel writes
$wr = New-Object System.IO.StreamWriter($n.Open()); $wr.Write($xml); $wr.Close()
$zip.Dispose()
Write-Output "saved $out"
