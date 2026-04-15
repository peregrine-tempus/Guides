# Builds RSCS_EDW_NLP_POC.pptx using PowerPoint COM automation.
# Requires Microsoft PowerPoint installed on the machine running this script.

$ErrorActionPreference = 'Stop'

$here        = Split-Path -Parent $MyInvocation.MyCommand.Path
$outPath     = Join-Path $here 'RSCS_EDW_NLP_POC.pptx'
$svgCurrent  = Join-Path $here 'EDW_Data_Fabric.svg'
$svgFuture   = Join-Path $here 'EDW_Data_Fabric_NLP.svg'

if (Test-Path $outPath) { Remove-Item $outPath -Force }

# Brand colors
$red    = 0x002625E3  # BGR for R=227 G=37 B=38
$purple = 0x0090496B  # BGR for R=107 G=73 B=144
$green  = 0x00459E4C  # BGR for R=76  G=158 B=69
$orange = 0x002D8DF6  # BGR for R=246 G=141 B=45
$dark   = 0x00222222
$gray   = 0x00666666
$light  = 0x00FAFAFA
$white  = 0x00FFFFFF

function RGB ($r,$g,$b) { return ($b -shl 16) -bor ($g -shl 8) -bor $r }
$cRed    = RGB 227 37 38
$cPurple = RGB 107 73 144
$cGreen  = RGB 76 158 69
$cOrange = RGB 246 141 45
$cDark   = RGB 34 34 34
$cGray   = RGB 102 102 102
$cMute   = RGB 136 136 136
$cLight  = RGB 250 250 250
$cWhite  = RGB 255 255 255
$cBgPanel = RGB 245 243 248

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
$pres = $ppt.Presentations.Add()

# Force 16:9 widescreen
$pres.PageSetup.SlideSize = 15  # ppSlideSizeOnScreen16x9
$slideWidth  = $pres.PageSetup.SlideWidth     # 960
$slideHeight = $pres.PageSetup.SlideHeight    # 540

# Constants
$msoShapeRectangle     = 1
$msoShapeRoundedRect   = 5
$msoTrue  = -1
$msoFalse = 0
$ppLayoutBlank = 12
$ppAlignCenter = 2
$ppAlignLeft   = 1

function Add-Slide {
    param($pres)
    $idx = $pres.Slides.Count + 1
    return $pres.Slides.Add($idx, $ppLayoutBlank)
}

function Set-Background {
    param($slide, [int]$color)
    $slide.FollowMasterBackground = $msoFalse
    $slide.Background.Fill.Visible = $msoTrue
    $slide.Background.Fill.ForeColor.RGB = $color
    $slide.Background.Fill.Solid()
}

function Add-Text {
    param($slide, $left, $top, $width, $height, $text, $size=18, [int]$color=0, [bool]$bold=$false, [int]$align=1, $font='Segoe UI')
    $box = $slide.Shapes.AddTextbox(1, $left, $top, $width, $height)
    $box.Line.Visible = $msoFalse
    $tf = $box.TextFrame
    $tf.WordWrap = $msoTrue
    $tf.MarginLeft = 0; $tf.MarginRight = 0; $tf.MarginTop = 0; $tf.MarginBottom = 0
    $tr = $tf.TextRange
    $tr.Text = $text
    $tr.Font.Name = $font
    $tr.Font.Size = $size
    $tr.Font.Color.RGB = $color
    if ($bold) { $tr.Font.Bold = $msoTrue } else { $tr.Font.Bold = $msoFalse }
    $tr.ParagraphFormat.Alignment = $align
    return $box
}

function Add-Bar {
    param($slide, $left, $top, $width, $height, [int]$color)
    $s = $slide.Shapes.AddShape($msoShapeRectangle, $left, $top, $width, $height)
    $s.Line.Visible = $msoFalse
    $s.Fill.ForeColor.RGB = $color
    $s.Fill.Solid()
    return $s
}

function Add-Footer {
    param($slide, $num, $total, $title='RSCS  -  EDW Natural-Language Query POC')
    Add-Bar $slide 0 525 960 15 (RGB 107 73 144) | Out-Null
    Add-Text $slide 30 528 600 14 $title 9 (RGB 255 255 255) $false 1 | Out-Null
    Add-Text $slide 860 528 80 14 "$num / $total" 9 (RGB 255 255 255) $false 3 | Out-Null
}

$totalSlides = 14

# ==========================================================================
# SLIDE 1  -  Title
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 8 $cRed | Out-Null
Add-Bar $s 0 8 960 4 $cPurple | Out-Null
Add-Bar $s 0 12 960 3 $cGreen | Out-Null
Add-Bar $s 0 15 960 2 $cOrange | Out-Null

Add-Text $s 60 160 840 60 "Natural-Language Queries Against Our EDW" 36 $cDark $true 1 | Out-Null
Add-Text $s 60 225 840 40 "A proof-of-concept, and what it tells us about where we go next" 18 $cGray $false 1 | Out-Null

Add-Bar $s 380 290 200 3 $cPurple | Out-Null

Add-Text $s 60 320 840 26 "EDW Architecture Review" 16 $cDark $true 1 | Out-Null
Add-Text $s 60 346 840 22 "Presented to: Director, Architect, Engineers, QA" 12 $cGray $false 1 | Out-Null
Add-Text $s 60 370 840 22 "30 minutes + 10-minute live demo" 12 $cGray $false 1 | Out-Null

Add-Footer $s 1 $totalSlides

# ==========================================================================
# SLIDE 2  -  Agenda
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cPurple | Out-Null
Add-Text $s 40 30 880 40 "Agenda" 28 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cRed | Out-Null

$agenda = @(
    @("1", "The problem we are trying to solve", $cRed),
    @("2", "Today's EDW  -  where we are", $cPurple),
    @("3", "The vision  -  Gold and Platinum in Microsoft Fabric", $cGreen),
    @("4", "The POC  -  what I built and why", $cOrange),
    @("5", "Live demo  -  3 questions, easy to hard", $cRed),
    @("6", "The real future  -  Fabric Data Agents + Azure OpenAI", $cPurple),
    @("7", "What I want from you today", $cGreen)
)

$y = 110
foreach ($item in $agenda) {
    $num = $item[0]; $text = $item[1]; $col = [int]$item[2]
    $circ = $s.Shapes.AddShape(9, 60, $y, 40, 40)  # msoShapeOval
    $circ.Line.Visible = $msoFalse
    $circ.Fill.ForeColor.RGB = $col
    $circ.Fill.Solid()
    $circ.TextFrame.TextRange.Text = $num
    $circ.TextFrame.TextRange.Font.Name = 'Segoe UI'
    $circ.TextFrame.TextRange.Font.Size = 16
    $circ.TextFrame.TextRange.Font.Bold = $msoTrue
    $circ.TextFrame.TextRange.Font.Color.RGB = $cWhite
    $circ.TextFrame.TextRange.ParagraphFormat.Alignment = $ppAlignCenter

    Add-Text $s 120 ($y+6) 780 30 $text 17 $cDark $false 1 | Out-Null
    $y += 55
}

Add-Footer $s 2 $totalSlides

# ==========================================================================
# SLIDE 3  -  The Problem
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cRed | Out-Null
Add-Text $s 40 30 880 40 "The problem" 28 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cRed | Out-Null

Add-Text $s 60 110 840 30 "Our data is rich. Access is not." 20 $cDark $true 1 | Out-Null

$problems = @(
    @("Learning curve", "HR says it takes roughly two years of experience before a new analyst can confidently talk about our data model. That is two years of onboarding tax on every new hire."),
    @("Gatekeeping bottleneck", "Business users with questions file tickets. Engineers write SQL. Reports get built. A 10-minute question becomes a 3-day turnaround."),
    @("Reports don't cover everything", "Power BI reports answer the top 80%. The remaining 20%  -  the ad-hoc, one-off, 'what if' questions  -  fall through the cracks.")
)

$y = 160
foreach ($p in $problems) {
    $title = $p[0]; $body = $p[1]
    Add-Bar $s 60 ($y+6) 6 90 $cRed | Out-Null
    Add-Text $s 85 $y 820 28 $title 16 $cDark $true 1 | Out-Null
    Add-Text $s 85 ($y+28) 820 65 $body 13 $cGray $false 1 | Out-Null
    $y += 110
}

Add-Footer $s 3 $totalSlides

# ==========================================================================
# SLIDE 4  -  Today's EDW
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cPurple | Out-Null
Add-Text $s 40 30 880 40 "Today's EDW" 28 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cPurple | Out-Null
Add-Text $s 40 78 880 22 "Medallion architecture on SQL Server 2022 and SSAS" 13 $cGray $false 1 | Out-Null

$layers = @(
    @("Bronze", "Raw ingest", $cMute),
    @("Silver", "Cleansed, conformed", $cMute),
    @("Gold", "Star schema on SQL Server 2022", $cGreen),
    @("Platinum", "SSAS OLAP cubes", $cOrange)
)

$x = 60
$boxW = 200
$gap = 15
foreach ($l in $layers) {
    $name = $l[0]; $desc = $l[1]; $col = [int]$l[2]
    $r = $s.Shapes.AddShape($msoShapeRoundedRect, $x, 140, $boxW, 150)
    $r.Adjustments.Item(1) = 0.15
    $r.Line.ForeColor.RGB = $col
    $r.Line.Weight = 2.5
    $r.Fill.ForeColor.RGB = $cWhite
    $r.Fill.Solid()
    Add-Text $s $x 165 $boxW 30 $name 20 $col $true 1 | Out-Null
    Add-Text $s ($x+10) 210 ($boxW-20) 60 $desc 12 $cGray $false 1 | Out-Null
    if ($l[0] -ne 'Platinum') {
        $arrow = $s.Shapes.AddLine(($x+$boxW+2), 215, ($x+$boxW+$gap-2), 215)
        $arrow.Line.ForeColor.RGB = $cDark
        $arrow.Line.Weight = 2
        $arrow.Line.EndArrowheadStyle = 2
    }
    $x += $boxW + $gap
}

Add-Text $s 60 320 840 30 "Consumers" 14 $cDark $true 1 | Out-Null
Add-Bar $s 60 345 840 1 $cMute | Out-Null
Add-Text $s 60 355 840 25 "Power BI  •  Excel  •  SSMS ad-hoc  •  Tickets to the EDW team" 14 $cGray $false 1 | Out-Null

Add-Text $s 60 410 840 30 "What is not in this picture" 14 $cRed $true 1 | Out-Null
Add-Bar $s 60 435 840 1 $cRed | Out-Null
Add-Text $s 60 445 840 25 "A way for someone to ask a question in plain English and get an answer." 14 $cDark $false 1 | Out-Null
Add-Text $s 60 470 840 25 "Every path to the data still requires SQL, DAX, or a filed ticket." 14 $cGray $false 1 | Out-Null

Add-Footer $s 4 $totalSlides

# ==========================================================================
# SLIDE 5  -  The Vision  -  Fabric diagram
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cGreen | Out-Null
Add-Text $s 40 30 880 40 "The vision  -  Gold and Platinum in Microsoft Fabric" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cGreen | Out-Null
Add-Text $s 40 78 880 22 "The plan getting the most attention today: lift Gold and Platinum into Fabric; Power BI connects natively." 12 $cGray $false 1 | Out-Null

$pic = $s.Shapes.AddPicture($svgCurrent, $msoFalse, $msoTrue, 40, 110, 880, 390)
$pic.LockAspectRatio = $msoTrue

Add-Footer $s 5 $totalSlides

# ==========================================================================
# SLIDE 6  -  Why Fabric
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cGreen | Out-Null
Add-Text $s 40 30 880 40 "Why Fabric  -  and why it is a hard sell" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cGreen | Out-Null

Add-Text $s 60 110 420 26 "What Fabric buys us" 16 $cGreen $true 1 | Out-Null
$pros = @(
    "OneLake  -  one governed copy of data, no duplication",
    "Direct Lake  -  Power BI without import lag or refresh windows",
    "Built-in governance via Purview and Entra ID",
    "Unlocks Fabric Data Agents + Azure OpenAI for free",
    "CI/CD through Fabric Git integration"
)
$y = 140
foreach ($p in $pros) {
    Add-Text $s 60 $y 20 22 "•" 14 $cGreen $true 1 | Out-Null
    Add-Text $s 80 $y 400 22 $p 12 $cDark $false 1 | Out-Null
    $y += 30
}

Add-Text $s 500 110 420 26 "Why it is hard to sell" 16 $cRed $true 1 | Out-Null
$cons = @(
    "Licensing cost  -  capacity SKUs are not cheap",
    "Migration risk  -  moving Gold and Platinum is real work",
    "Team ramp-up  -  new tooling, new monitoring, new CI/CD",
    "Perceived as 'just another rebrand' of synapse/PBI Premium",
    "No compelling AI story yet  -  until today"
)
$y = 140
foreach ($p in $cons) {
    Add-Text $s 500 $y 20 22 "•" 14 $cRed $true 1 | Out-Null
    Add-Text $s 520 $y 400 22 $p 12 $cDark $false 1 | Out-Null
    $y += 30
}

Add-Bar $s 60 330 860 2 $cPurple | Out-Null
Add-Text $s 60 345 860 26 "The missing pitch" 14 $cPurple $true 1 | Out-Null
Add-Text $s 60 372 860 60 "Fabric's AI story is the strongest argument no one is making yet. Data Agents and Azure OpenAI natively grounded on our own semantic model change the conversation from 'migration project' to 'capability unlock'. That is what this POC is meant to show." 12 $cDark $false 1 | Out-Null

Add-Footer $s 6 $totalSlides

# ==========================================================================
# SLIDE 7  -  The POC  -  what I built
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cOrange | Out-Null
Add-Text $s 40 30 880 40 "The POC  -  what I built" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cOrange | Out-Null
Add-Text $s 40 78 880 22 "A .NET 10 REST service that takes a plain-English question and returns generated T-SQL + a plain-English answer." 12 $cGray $false 1 | Out-Null

$pipeline = @(
    @("1. Question",      "HTTP POST",                 $cGray),
    @("2. Schema",        "sys.* catalog + FK chains", $cPurple),
    @("3. Generate SQL",  "Local LLM (Ollama)",        $cOrange),
    @("4. Safety check",  "SELECT-only guardrail",     $cRed),
    @("5. Execute",       "Read-only transaction",     $cGreen),
    @("6. Synthesize",    "LLM to plain English",      $cOrange)
)
$x = 40
$w = 145
foreach ($stage in $pipeline) {
    $title = $stage[0]; $sub = $stage[1]; $col = [int]$stage[2]
    $r = $s.Shapes.AddShape($msoShapeRoundedRect, $x, 125, $w, 75)
    $r.Adjustments.Item(1) = 0.15
    $r.Line.ForeColor.RGB = $col
    $r.Line.Weight = 2
    $r.Fill.ForeColor.RGB = $cWhite
    $r.Fill.Solid()
    Add-Text $s $x 135 $w 22 $title 12 $col $true 1 | Out-Null
    Add-Text $s ($x+5) 165 ($w-10) 30 $sub 10 $cGray $false 1 | Out-Null
    $x += $w + 7
}

Add-Text $s 40 220 880 26 "Design principles" 14 $cDark $true 1 | Out-Null
Add-Bar $s 40 246 880 1 $cMute | Out-Null

$principles = @(
    @("Schema-agnostic", "No table names, column names, or join hints in code or config. Point it at any SQL Server database."),
    @("FK chain walking", "Annotates columns with reachable terminal tables  -  solves multi-hop join hallucinations generically."),
    @("Two-model pipeline", "One model generates SQL, a second model synthesizes the human answer  -  each tuned for its job."),
    @("3-attempt retry", "If generated SQL fails to execute, regenerate with the error message in the next prompt."),
    @("Read-only", "SELECT-only regex guard. Blocked keyword list. Read-only transaction. No caching, no history, no faking.")
)
$y = 260
foreach ($p in $principles) {
    $title = $p[0]; $body = $p[1]
    Add-Text $s 60 $y 180 22 $title 12 $cOrange $true 1 | Out-Null
    Add-Text $s 250 $y 680 22 $body 11 $cGray $false 1 | Out-Null
    $y += 28
}

Add-Footer $s 7 $totalSlides

# ==========================================================================
# SLIDE 8  -  Honest caveat
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cRed | Out-Null
Add-Text $s 40 30 880 40 "Before the demo  -  things you should know" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cRed | Out-Null

$caveats = @(
    @("It will be slow",       "A 7B-parameter model running on 8 GB of VRAM on a workstation. Expect 30-90 seconds per question. Azure OpenAI does this in 2-4 seconds."),
    @("It will sometimes fail", "Local models hallucinate. The safety guard catches destructive SQL. The retry loop recovers from most execution errors. Some questions still won't land cleanly."),
    @("It is not a replacement for reports", "This is a research aid and a learning aid. The SQL it returns helps users understand how to ask their own questions. Decisions should still be grounded in reviewed reports."),
    @("It is a learning shortcut", "Two-year ramp on our data model? This lets a new hire ask 'what tables do I join to find X' and get a working answer today.")
)
$y = 115
foreach ($c in $caveats) {
    $title = $c[0]; $body = $c[1]
    Add-Bar $s 60 ($y+6) 6 75 $cRed | Out-Null
    Add-Text $s 85 $y 820 24 $title 14 $cDark $true 1 | Out-Null
    Add-Text $s 85 ($y+26) 820 60 $body 11 $cGray $false 1 | Out-Null
    $y += 95
}

Add-Footer $s 8 $totalSlides

# ==========================================================================
# SLIDE 9  -  Demo prep
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cRed | Out-Null
Add-Text $s 40 30 880 40 "Live demo  -  three questions" 26 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cRed | Out-Null
Add-Text $s 40 78 880 22 "Each question is pre-loaded in a Postman tab. I'll also take one question from the audience." 12 $cGray $false 1 | Out-Null

$qs = @(
    @("Easy",   "How many products do we sell?",                                                         "Single table, single aggregate. Validates the pipeline end-to-end.",                    $cGreen),
    @("Medium", "What are our top 5 product categories by total sales amount?",                          "Multi-table join, GROUP BY, ORDER BY, TOP. This is the FK chain walking test.",          $cOrange),
    @("Hard",   "Which resellers had the highest year-over-year sales growth between 2012 and 2013?",    "Date arithmetic, self-join or CTE, percentage calculation, filtering. The stress test.", $cRed)
)

$y = 115
foreach ($q in $qs) {
    $level = $q[0]; $question = $q[1]; $why = $q[2]; $col = [int]$q[3]
    $r = $s.Shapes.AddShape($msoShapeRoundedRect, 40, $y, 880, 115)
    $r.Adjustments.Item(1) = 0.1
    $r.Line.ForeColor.RGB = $col
    $r.Line.Weight = 2
    $r.Fill.ForeColor.RGB = $cWhite
    $r.Fill.Solid()

    Add-Bar $s 40 $y 12 115 $col | Out-Null
    Add-Text $s 65 ($y+12) 120 24 $level 14 $col $true 1 | Out-Null
    Add-Text $s 65 ($y+36) 820 32 ('"' + $question + '"') 16 $cDark $true 1 | Out-Null
    Add-Text $s 65 ($y+72) 820 40 $why 11 $cGray $false 1 | Out-Null
    $y += 125
}

Add-Bar $s 40 495 880 2 $cPurple | Out-Null
Add-Text $s 40 500 880 22 "Plus one audience question  -  bring your best AdventureWorks curveball." 12 $cPurple $true 1 | Out-Null

Add-Footer $s 9 $totalSlides

# ==========================================================================
# SLIDE 10  -  DEMO placeholder
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cDark
Add-Text $s 40 200 880 80 "DEMO" 96 $cWhite $true 1 | Out-Null
Add-Text $s 40 310 880 40 "Switch to Postman" 24 (RGB 220 220 220) $false 1 | Out-Null
Add-Bar $s 430 370 100 3 $cOrange | Out-Null
Add-Text $s 40 390 880 30 "approx. 10 minutes" 14 (RGB 180 180 180) $false 1 | Out-Null

Add-Footer $s 10 $totalSlides

# ==========================================================================
# SLIDE 11  -  The real future  -  Fabric Data Agents diagram
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cPurple | Out-Null
Add-Text $s 40 30 880 40 "The real future  -  native Fabric Data Agents" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cPurple | Out-Null
Add-Text $s 40 78 880 22 "Everything the POC does, but grounded on the Platinum semantic model and powered by Azure OpenAI." 12 $cGray $false 1 | Out-Null

$pic = $s.Shapes.AddPicture($svgFuture, $msoFalse, $msoTrue, 30 , 105, 900, 395)
$pic.LockAspectRatio = $msoTrue

Add-Footer $s 11 $totalSlides

# ==========================================================================
# SLIDE 12  -  POC vs Fabric native
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cPurple | Out-Null
Add-Text $s 40 30 880 40 "POC vs. the Fabric-native path" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cPurple | Out-Null

$headerY = 110
Add-Bar $s 40 $headerY 880 32 $cPurple | Out-Null
Add-Text $s 55 ($headerY+6) 300 22 "Dimension" 13 $cWhite $true 1 | Out-Null
Add-Text $s 360 ($headerY+6) 270 22 "Today's POC" 13 $cWhite $true 1 | Out-Null
Add-Text $s 640 ($headerY+6) 270 22 "Fabric Data Agent" 13 $cWhite $true 1 | Out-Null

$rows = @(
    @("Model",           "Local Ollama 7B",                  "Azure OpenAI GPT-4o"),
    @("Grounding",       "Raw schema + FK walk",             "Platinum semantic model + glossary"),
    @("Latency",         "30-90 seconds",                    "2-4 seconds"),
    @("Security",        "Connection-string user",           "Entra ID + RLS/OLS inherited"),
    @("Audit and lineage","None",                            "Purview, built-in"),
    @("Hosting",         "Your workstation",                 "Microsoft-managed"),
    @("Maintenance",     "Me",                               "Near zero")
)
$y = $headerY + 32
$alt = $true
foreach ($r in $rows) {
    if ($alt) { Add-Bar $s 40 $y 880 32 $cBgPanel | Out-Null }
    Add-Text $s 55 ($y+6) 300 22 $r[0] 12 $cDark $true 1 | Out-Null
    Add-Text $s 360 ($y+6) 270 22 $r[1] 12 $cGray $false 1 | Out-Null
    Add-Text $s 640 ($y+6) 270 22 $r[2] 12 $cDark $false 1 | Out-Null
    $y += 32
    $alt = -not $alt
}

Add-Text $s 40 385 880 22 "Bottom line" 13 $cDark $true 1 | Out-Null
Add-Bar $s 40 408 880 1 $cMute | Out-Null
Add-Text $s 40 418 880 80 "The POC answers 'is this possible?'  -  yes. Fabric answers 'is this supportable?'  -  also yes, and without any of the infrastructure we had to build by hand. Every bullet on the right is checked by Microsoft, not by us." 13 $cGray $false 1 | Out-Null

Add-Footer $s 12 $totalSlides

# ==========================================================================
# SLIDE 13  -  A note on MCP
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cPurple | Out-Null
Add-Text $s 40 30 880 40 "An honest note on MCP" 24 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cPurple | Out-Null
Add-Text $s 40 78 880 22 "VSLive! sent me down a rabbit hole. Here is where I landed." 12 $cGray $false 1 | Out-Null

Add-Text $s 60 115 880 26 "What MCP actually is" 14 $cPurple $true 1 | Out-Null
Add-Text $s 60 140 880 45 "A standard transport (JSON-RPC) that lets external LLM clients  -  Claude Desktop, VS Code Copilot, Cursor  -  invoke tools and read data from proprietary systems. The client is an AI assistant someone else built." 11 $cGray $false 1 | Out-Null

Add-Text $s 60 200 880 26 "What I built" 14 $cOrange $true 1 | Out-Null
Add-Text $s 60 225 880 45 "A REST service that uses a local LLM to translate questions into SQL. No external LLM client is involved. Nothing on the other side of the wire speaks MCP to us. The 'MCP' in the project name is vocabulary, not protocol." 11 $cGray $false 1 | Out-Null

Add-Text $s 60 285 880 26 "So do we need MCP for this? No." 14 $cRed $true 1 | Out-Null
Add-Text $s 60 310 880 45 "For business-user self-service BI, MCP is the wrong layer. The POC works; it just needs a rename  -  not a rewrite. See REFACTOR.md for the mechanical change set." 11 $cGray $false 1 | Out-Null

Add-Text $s 60 370 880 26 "Where MCP would actually shine" 14 $cGreen $true 1 | Out-Null
Add-Text $s 60 395 880 45 "If we wanted our EDW queryable from inside Claude, VS Code, or Cursor for developers and analysts  -  that is a real, legitimate MCP use case. Different audience than this project, but worth keeping on the roadmap." 11 $cGray $false 1 | Out-Null

Add-Footer $s 13 $totalSlides

# ==========================================================================
# SLIDE 14  -  What I want from you
# ==========================================================================
$s = Add-Slide $pres
Set-Background $s $cWhite
Add-Bar $s 0 0 960 6 $cGreen | Out-Null
Add-Text $s 40 30 880 40 "What I want from you today" 26 $cDark $true 1 | Out-Null
Add-Bar $s 40 72 80 3 $cGreen | Out-Null
Add-Text $s 40 78 880 22 "Not a go/no-go. A gut check and a direction." 12 $cGray $false 1 | Out-Null

$asks = @(
    @("Feedback",   "Does this look like something our users would actually use? Where does it feel fragile? What would you not trust?"),
    @("Use cases",  "Which corners of our data model would benefit most? Where is the 2-year learning curve hurting us right now?"),
    @("The ask",    "Help me build the case for Fabric. If the AI story moves the needle for your stakeholders, say so  -  that is the argument I am missing."),
    @("Clear lane", "Agreement that this is a research/learning aid, not a replacement for governed reports. Decisions still come from reviewed BI.")
)
$y = 115
foreach ($a in $asks) {
    $title = $a[0]; $body = $a[1]
    $r = $s.Shapes.AddShape($msoShapeRoundedRect, 40, $y, 880, 80)
    $r.Adjustments.Item(1) = 0.2
    $r.Line.ForeColor.RGB = $cGreen
    $r.Line.Weight = 1.5
    $r.Fill.ForeColor.RGB = $cWhite
    $r.Fill.Solid()
    Add-Bar $s 40 $y 8 80 $cGreen | Out-Null
    Add-Text $s 65 ($y+10) 820 24 $title 14 $cGreen $true 1 | Out-Null
    Add-Text $s 65 ($y+36) 820 40 $body 12 $cGray $false 1 | Out-Null
    $y += 90
}

Add-Bar $s 40 485 880 2 $cPurple | Out-Null
Add-Text $s 40 495 880 30 "Thank you  -  questions?" 16 $cPurple $true 1 | Out-Null

Add-Footer $s 14 $totalSlides

# Save
$pres.SaveAs($outPath)
$pres.Close()
$ppt.Quit()

[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null
[System.GC]::Collect() | Out-Null
[System.GC]::WaitForPendingFinalizers() | Out-Null

Write-Host "Wrote $outPath"

