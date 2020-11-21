
# # https://github.com/EvotecIT/PSSharedGoods
# # https://github.com/EvotecIT/PSDiscord
function Get-DiscordConfig {
    [CmdletBinding()]
    param(
        [string] $Name = 'Primary'
    )
    [string] $Path = [IO.Path]::Combine($Env:USERPROFILE, '.psdiscord')
    [string] $PathXML = [IO.Path]::Combine($Path, "config.xml")

    if (Test-Path -Path $PathXML) {
        $Configuration = Import-Clixml -Path $PathXML
        if ($null -ne $Configuration.$Name) {
            return $Configuration.$Name
        }
    }
    return $null
}
function Initialize-DiscordConfig {
    [CmdletBinding()]
    param(
        [string] $Name = 'Primary',
        [Uri] $URI
    )
    [string] $Path = [IO.Path]::Combine($Env:USERPROFILE, '.psdiscord')
    [string] $PathXML = [IO.Path]::Combine($Path, "config.xml")
    # Creates required folder

    $Configuration = @{}
    $Configuration.$Name = $URI

    $null = New-Item -Path $Path -ItemType Directory -Force
    Export-Clixml -Path $PathXML -InputObject $Configuration -Force
}
function New-DiscordAuthor {
    [CmdletBinding()]
    param (
        [string] $Name,
        [Uri] $Url,
        [Uri] $IconUrl,
        [Uri] $ProxyUrlIcon
    )
    $script:Author = [ordered] @{
        name           = $Name
        url            = $Url
        icon_url       = $IconUrl
        proxy_icon_url = $ProxyUrlIcon
    }
    return $Author
}
function New-DiscordFact {
    [alias("New-DiscordField")]
    [CmdletBinding()]
    param (
        [string] $Name,
        [string] $Value,
        [bool] $Inline
    )

    If ($Name -ne '' -and $Value -ne '') {
        $script:Fact = [ordered] @{
            name   = $Name
            value  = $Value
            inline = $inline
        }
        return $Fact
    }
}
function New-DiscordImage {
    [alias('New-DiscordThumbnail')]
    [CmdletBinding()]
    param (
        [Uri] $Url,
        [int] $Width,
        [int] $Height
    )
    $script:Thumbnail = [ordered] @{
        "url"    = $Url
        "width"  = $Width
        "height" = $Height
    }
    return $Thumbnail
}
function New-DiscordSection {
    [alias("New-DiscordEmbed")]
    [CmdletBinding()]
    param (
        [string] $Title,
        [string] $Description,
        [alias('Fields')][System.Collections.IDictionary[]] $Facts,
        [RGBColors] $Color,
        [System.Collections.IDictionary] $Author,
        [System.Collections.IDictionary] $Thumbnail,
        [System.Collections.IDictionary] $Image
    )
    $script:Section = [ordered] @{
        title       = $Title
        description = $Description
        fields      = @()
    }
    $script:Field = foreach ($Fact in $Facts) {
        if ($null -ne $Fact) {
            $script:Fact
        }
    }
    $script:Section.fields = @($Field)
     if ($null -ne $Color) {
         $script:Section.color = ConvertFrom-Color -Color $Color -AsDecimal
    }
    if ($null -ne $Author) {
        $script:Section.author = $Author
    }
    if ($null -ne $Image) {
        $script:Section.image = $Image
    }
    if ($null -ne $Thumbnail) {
        $script:Section.thumbnail = $Thumbnail
    }
    return $Section
}
function Send-DiscordMessage {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [alias('Url', 'Uri')][Uri] $WebHookUrl,
        [alias('Embeds', 'Embed', 'Section')][System.Collections.IDictionary[]] $Sections,
        [alias('Content', 'Message')][string] $Text,
        [alias('Username')] [string] $AvatarName,
        [Uri] $AvatarUrl,
        [alias('TTS')][switch] $TextToSpeech,
        [switch] $CreateConfig,
        [string] $ConfigName,
        [switch] $OutputJSON
    )
    if (-not $WebHookUrl) {
        $script:WebHookUrl = Get-DiscordConfig -Name 'Primary'
    }
    if ($null -eq $WebHookUrl) {
        Write-Warning 'Send-DiscordMessage - WebhookUrl is not set. Either provide it as parameter or initialize it with config.'
    }
    if ($CreateConfig) {
        if (-not $ConfigName) {
            $script:ConfigName = 'Primary'
        }
        Initialize-DiscordConfig -ConfigName $ConfigName -URI $WebHookUrl
    }
    $script:FullMessage = [ordered] @{
        "embeds" = @()
    }
    if ($null -ne $Sections) {
        foreach ($Section in $Sections) {
            $FullMessage.embeds += $Section
        }
    }
    if ($null -ne $Text) {
        if ($TextToSpeech) {
            # Applies only to Content
            $FullMessage.tts = $true
        }
        $script:FullMessage.content = $Text
    }
    if ($null -ne $AvatarName) {
        $script:FullMessage.username = $AvatarName
    }
    if ($null -ne $AvatarUrl) {
        $script:FullMessage.avatar_url = $AvatarUrl
    }

    $Body = ConvertTo-Json -Depth 6 -InputObject $FullMessage
    Write-Verbose -Message "Send-DiscordMessage - Body: `n$Body"
    if ($PSCmdlet.ShouldProcess("$([System.Environment]::NewLine)$Body", 'Invoke-RestMethod')) {
        Invoke-RestMethod -Uri $WebHookUrl -Body $Body -Method Post -ContentType "application/json" -Verbose:$false
    }
    if ($OutputJSON) {
        return $Body
    }
}

function ConvertFrom-Color {
    [alias('Convert-FromColor')]
    [CmdletBinding()]
    param (
        [ValidateScript( {
                if ($($_ -in $script:RGBColors.Keys -or $_ -match "^#([A-Fa-f0-9]{6})$" -or $_ -eq "") -eq $false) {
                    throw "The Input value is not a valid colorname nor an valid color hex code."
                } else { $true }
            })]
        [alias('Colors')][string[]] $Color,
        [switch] $AsDecimal
    )
    $Colors = foreach ($C in $Color) {
        $Value = $script:RGBColors."$C"
        if ($C -match "^#([A-Fa-f0-9]{6})$") {
            return $C
        }
        if ($null -eq $Value) {
            return
        }
        $HexValue = Convert-Color -RGB $Value
        Write-Verbose "Convert-FromColor - Color Name: $C Value: $Value HexValue: $HexValue"
        if ($AsDecimal) {
            [Convert]::ToInt64($HexValue, 16)
        } else {
            "#$($HexValue)"
        }
    }
    $Colors
}
$script:RGBColors = [ordered] @{
    None                   = $null
    AirForceBlue           = 93, 138, 168
    Akaroa                 = 195, 176, 145
    AlbescentWhite         = 227, 218, 201
    AliceBlue              = 240, 248, 255
    Alizarin               = 227, 38, 54
    Allports               = 18, 97, 128
    Almond                 = 239, 222, 205
    AlmondFrost            = 159, 129, 112
    Amaranth               = 229, 43, 80
    Amazon                 = 59, 122, 87
    Amber                  = 255, 191, 0
    Amethyst               = 153, 102, 204
    AmethystSmoke          = 156, 138, 164
    AntiqueWhite           = 250, 235, 215
    Apple                  = 102, 180, 71
    AppleBlossom           = 176, 92, 82
    Apricot                = 251, 206, 177
    Aqua                   = 0, 255, 255
    Aquamarine             = 127, 255, 212
    Armygreen              = 75, 83, 32
    Arsenic                = 59, 68, 75
    Astral                 = 54, 117, 136
    Atlantis               = 164, 198, 57
    Atomic                 = 65, 74, 76
    AtomicTangerine        = 255, 153, 102
    Axolotl                = 99, 119, 91
    Azure                  = 240, 255, 255
    Bahia                  = 176, 191, 26
    BakersChocolate        = 93, 58, 26
    BaliHai                = 124, 152, 171
    BananaMania            = 250, 231, 181
    BattleshipGrey         = 85, 93, 80
    BayOfMany              = 35, 48, 103
    Beige                  = 245, 245, 220
    Bermuda                = 136, 216, 192
    Bilbao                 = 42, 128, 0
    BilobaFlower           = 181, 126, 220
    Bismark                = 83, 104, 114
    Bisque                 = 255, 228, 196
    Bistre                 = 61, 43, 31
    Bittersweet            = 254, 111, 94
    Black                  = 0, 0, 0
    BlackPearl             = 31, 38, 42
    BlackRose              = 85, 31, 47
    BlackRussian           = 23, 24, 43
    BlanchedAlmond         = 255, 235, 205
    BlizzardBlue           = 172, 229, 238
    Blue                   = 0, 0, 255
    BlueDiamond            = 77, 26, 127
    BlueMarguerite         = 115, 102, 189
    BlueSmoke              = 115, 130, 118
    BlueViolet             = 138, 43, 226
    Blush                  = 169, 92, 104
    BokaraGrey             = 22, 17, 13
    Bole                   = 121, 68, 59
    BondiBlue              = 0, 147, 175
    Bordeaux               = 88, 17, 26
    Bossanova              = 86, 60, 92
    Boulder                = 114, 116, 114
    Bouquet                = 183, 132, 167
    Bourbon                = 170, 108, 57
    Brass                  = 181, 166, 66
    BrickRed               = 199, 44, 72
    BrightGreen            = 102, 255, 0
    BrightRed              = 146, 43, 62
    BrightTurquoise        = 8, 232, 222
    BrilliantRose          = 243, 100, 162
    BrinkPink              = 250, 110, 121
    BritishRacingGreen     = 0, 66, 37
    Bronze                 = 205, 127, 50
    Brown                  = 165, 42, 42
    BrownPod               = 57, 24, 2
    BuddhaGold             = 202, 169, 6
    Buff                   = 240, 220, 130
    Burgundy               = 128, 0, 32
    BurlyWood              = 222, 184, 135
    BurntOrange            = 255, 117, 56
    BurntSienna            = 233, 116, 81
    BurntUmber             = 138, 51, 36
    ButteredRum            = 156, 124, 56
    CadetBlue              = 95, 158, 160
    California             = 224, 141, 60
    CamouflageGreen        = 120, 134, 107
    Canary                 = 255, 255, 153
    CanCan                 = 217, 134, 149
    CannonPink             = 145, 78, 117
    CaputMortuum           = 89, 39, 32
    Caramel                = 255, 213, 154
    Cararra                = 237, 230, 214
    Cardinal               = 179, 33, 52
    CardinGreen            = 18, 53, 36
    CareysPink             = 217, 152, 160
    CaribbeanGreen         = 0, 222, 164
    Carmine                = 175, 0, 42
    CarnationPink          = 255, 166, 201
    CarrotOrange           = 242, 142, 28
    Cascade                = 141, 163, 153
    CatskillWhite          = 226, 229, 222
    Cedar                  = 67, 48, 46
    Celadon                = 172, 225, 175
    Celeste                = 207, 207, 196
    Cello                  = 55, 79, 107
    Cement                 = 138, 121, 93
    Cerise                 = 222, 49, 99
    Cerulean               = 0, 123, 167
    CeruleanBlue           = 42, 82, 190
    Chantilly              = 239, 187, 204
    Chardonnay             = 255, 200, 124
    Charlotte              = 167, 216, 222
    Charm                  = 208, 116, 139
    Chartreuse             = 127, 255, 0
    ChartreuseYellow       = 223, 255, 0
    ChelseaCucumber        = 135, 169, 107
    Cherub                 = 246, 214, 222
    Chestnut               = 185, 78, 72
    ChileanFire            = 226, 88, 34
    Chinook                = 150, 200, 162
    Chocolate              = 210, 105, 30
    Christi                = 125, 183, 0
    Christine              = 181, 101, 30
    Cinnabar               = 235, 76, 66
    Citron                 = 159, 169, 31
    Citrus                 = 141, 182, 0
    Claret                 = 95, 25, 51
    ClassicRose            = 251, 204, 231
    ClayCreek              = 145, 129, 81
    Clinker                = 75, 54, 33
    Clover                 = 74, 93, 35
    Cobalt                 = 0, 71, 171
    CocoaBrown             = 44, 22, 8
    Cola                   = 60, 48, 36
    ColumbiaBlue           = 166, 231, 255
    CongoBrown             = 103, 76, 71
    Conifer                = 178, 236, 93
    Copper                 = 218, 138, 103
    CopperRose             = 153, 102, 102
    Coral                  = 255, 127, 80
    CoralRed               = 255, 64, 64
    CoralTree              = 173, 111, 105
    Coriander              = 188, 184, 138
    Corn                   = 251, 236, 93
    CornField              = 250, 240, 190
    Cornflower             = 147, 204, 234
    CornflowerBlue         = 100, 149, 237
    Cornsilk               = 255, 248, 220
    Cosmic                 = 132, 63, 91
    Cosmos                 = 255, 204, 203
    CostaDelSol            = 102, 93, 30
    CottonCandy            = 255, 188, 217
    Crail                  = 164, 90, 82
    Cranberry              = 205, 96, 126
    Cream                  = 255, 255, 204
    CreamCan               = 242, 198, 73
    Crimson                = 220, 20, 60
    Crusta                 = 232, 142, 90
    Cumulus                = 255, 255, 191
    Cupid                  = 246, 173, 198
    CuriousBlue            = 40, 135, 200
    Cyan                   = 0, 255, 255
    Cyprus                 = 6, 78, 64
    DaisyBush              = 85, 53, 146
    Dandelion              = 250, 218, 94
    Danube                 = 96, 130, 182
    DarkBlue               = 0, 0, 139
    DarkBrown              = 101, 67, 33
    DarkCerulean           = 8, 69, 126
    DarkChestnut           = 152, 105, 96
    DarkCoral              = 201, 90, 73
    DarkCyan               = 0, 139, 139
    DarkGoldenrod          = 184, 134, 11
    DarkGray               = 169, 169, 169
    DarkGreen              = 0, 100, 0
    DarkGreenCopper        = 73, 121, 107
    DarkGrey               = 169, 169, 169
    DarkKhaki              = 189, 183, 107
    DarkMagenta            = 139, 0, 139
    DarkOliveGreen         = 85, 107, 47
    DarkOrange             = 255, 140, 0
    DarkOrchid             = 153, 50, 204
    DarkPastelGreen        = 3, 192, 60
    DarkPink               = 222, 93, 131
    DarkPurple             = 150, 61, 127
    DarkRed                = 139, 0, 0
    DarkSalmon             = 233, 150, 122
    DarkSeaGreen           = 143, 188, 143
    DarkSlateBlue          = 72, 61, 139
    DarkSlateGray          = 47, 79, 79
    DarkSlateGrey          = 47, 79, 79
    DarkSpringGreen        = 23, 114, 69
    DarkTangerine          = 255, 170, 29
    DarkTurquoise          = 0, 206, 209
    DarkViolet             = 148, 0, 211
    DarkWood               = 130, 102, 68
    DeepBlush              = 245, 105, 145
    DeepCerise             = 224, 33, 138
    DeepKoamaru            = 51, 51, 102
    DeepLilac              = 153, 85, 187
    DeepMagenta            = 204, 0, 204
    DeepPink               = 255, 20, 147
    DeepSea                = 14, 124, 97
    DeepSkyBlue            = 0, 191, 255
    DeepTeal               = 24, 69, 59
    Denim                  = 36, 107, 206
    DesertSand             = 237, 201, 175
    DimGray                = 105, 105, 105
    DimGrey                = 105, 105, 105
    DodgerBlue             = 30, 144, 255
    Dolly                  = 242, 242, 122
    Downy                  = 95, 201, 191
    DutchWhite             = 239, 223, 187
    EastBay                = 76, 81, 109
    EastSide               = 178, 132, 190
    EchoBlue               = 169, 178, 195
    Ecru                   = 194, 178, 128
    Eggplant               = 162, 0, 109
    EgyptianBlue           = 16, 52, 166
    ElectricBlue           = 125, 249, 255
    ElectricIndigo         = 111, 0, 255
    ElectricLime           = 208, 255, 20
    ElectricPurple         = 191, 0, 255
    Elm                    = 47, 132, 124
    Emerald                = 80, 200, 120
    Eminence               = 108, 48, 130
    Endeavour              = 46, 88, 148
    EnergyYellow           = 245, 224, 80
    Espresso               = 74, 44, 42
    Eucalyptus             = 26, 162, 96
    Falcon                 = 126, 94, 96
    Fallow                 = 204, 153, 102
    FaluRed                = 128, 24, 24
    Feldgrau               = 77, 93, 83
    Feldspar               = 205, 149, 117
    Fern                   = 113, 188, 120
    FernGreen              = 79, 121, 66
    Festival               = 236, 213, 64
    Finn                   = 97, 64, 81
    FireBrick              = 178, 34, 34
    FireBush               = 222, 143, 78
    FireEngineRed          = 211, 33, 45
    Flamingo               = 233, 92, 75
    Flax                   = 238, 220, 130
    FloralWhite            = 255, 250, 240
    ForestGreen            = 34, 139, 34
    Frangipani             = 250, 214, 165
    FreeSpeechAquamarine   = 0, 168, 119
    FreeSpeechRed          = 204, 0, 0
    FrenchLilac            = 230, 168, 215
    FrenchRose             = 232, 83, 149
    FriarGrey              = 135, 134, 129
    Froly                  = 228, 113, 122
    Fuchsia                = 255, 0, 255
    FuchsiaPink            = 255, 119, 255
    Gainsboro              = 220, 220, 220
    Gallery                = 219, 215, 210
    Galliano               = 204, 160, 29
    Gamboge                = 204, 153, 0
    Ghost                  = 196, 195, 208
    GhostWhite             = 248, 248, 255
    Gin                    = 216, 228, 188
    GinFizz                = 247, 231, 206
    Givry                  = 230, 208, 171
    Glacier                = 115, 169, 194
    Gold                   = 255, 215, 0
    GoldDrop               = 213, 108, 43
    GoldenBrown            = 150, 113, 23
    GoldenFizz             = 240, 225, 48
    GoldenGlow             = 248, 222, 126
    GoldenPoppy            = 252, 194, 0
    Goldenrod              = 218, 165, 32
    GoldenSand             = 233, 214, 107
    GoldenYellow           = 253, 238, 0
    GoldTips               = 225, 189, 39
    GordonsGreen           = 37, 53, 41
    Gorse                  = 255, 225, 53
    Gossamer               = 49, 145, 119
    GrannySmithApple       = 168, 228, 160
    Gray                   = 128, 128, 128
    GrayAsparagus          = 70, 89, 69
    Green                  = 0, 128, 0
    GreenLeaf              = 76, 114, 29
    GreenVogue             = 38, 67, 72
    GreenYellow            = 173, 255, 47
    Grey                   = 128, 128, 128
    GreyAsparagus          = 70, 89, 69
    GuardsmanRed           = 157, 41, 51
    GumLeaf                = 178, 190, 181
    Gunmetal               = 42, 52, 57
    Hacienda               = 155, 135, 12
    HalfAndHalf            = 232, 228, 201
    HalfBaked              = 95, 138, 139
    HalfColonialWhite      = 246, 234, 190
    HalfPearlLusta         = 240, 234, 214
    HanPurple              = 63, 0, 255
    Harlequin              = 74, 255, 0
    HarleyDavidsonOrange   = 194, 59, 34
    Heather                = 174, 198, 207
    Heliotrope             = 223, 115, 255
    Hemp                   = 161, 122, 116
    Highball               = 134, 126, 54
    HippiePink             = 171, 75, 82
    Hoki                   = 110, 127, 128
    HollywoodCerise        = 244, 0, 161
    Honeydew               = 240, 255, 240
    Hopbush                = 207, 113, 175
    HorsesNeck             = 108, 84, 30
    HotPink                = 255, 105, 180
    HummingBird            = 201, 255, 229
    HunterGreen            = 53, 94, 59
    Illusion               = 244, 152, 173
    InchWorm               = 202, 224, 13
    IndianRed              = 205, 92, 92
    Indigo                 = 75, 0, 130
    InternationalKleinBlue = 0, 24, 168
    InternationalOrange    = 255, 79, 0
    IrisBlue               = 28, 169, 201
    IrishCoffee            = 102, 66, 40
    IronsideGrey           = 113, 112, 110
    IslamicGreen           = 0, 144, 0
    Ivory                  = 255, 255, 240
    Jacarta                = 61, 50, 93
    JackoBean              = 65, 54, 40
    JacksonsPurple         = 46, 45, 136
    Jade                   = 0, 171, 102
    JapaneseLaurel         = 47, 117, 50
    Jazz                   = 93, 43, 44
    JazzberryJam           = 165, 11, 94
    JellyBean              = 68, 121, 142
    JetStream              = 187, 208, 201
    Jewel                  = 0, 107, 60
    Jon                    = 79, 58, 60
    JordyBlue              = 124, 185, 232
    Jumbo                  = 132, 132, 130
    JungleGreen            = 41, 171, 135
    KaitokeGreen           = 30, 77, 43
    Karry                  = 255, 221, 202
    KellyGreen             = 70, 203, 24
    Keppel                 = 93, 164, 147
    Khaki                  = 240, 230, 140
    Killarney              = 77, 140, 87
    KingfisherDaisy        = 85, 27, 140
    Kobi                   = 230, 143, 172
    LaPalma                = 60, 141, 13
    LaserLemon             = 252, 247, 94
    Laurel                 = 103, 146, 103
    Lavender               = 230, 230, 250
    LavenderBlue           = 204, 204, 255
    LavenderBlush          = 255, 240, 245
    LavenderPink           = 251, 174, 210
    LavenderRose           = 251, 160, 227
    LawnGreen              = 124, 252, 0
    LemonChiffon           = 255, 250, 205
    LightBlue              = 173, 216, 230
    LightCoral             = 240, 128, 128
    LightCyan              = 224, 255, 255
    LightGoldenrodYellow   = 250, 250, 210
    LightGray              = 211, 211, 211
    LightGreen             = 144, 238, 144
    LightGrey              = 211, 211, 211
    LightPink              = 255, 182, 193
    LightSalmon            = 255, 160, 122
    LightSeaGreen          = 32, 178, 170
    LightSkyBlue           = 135, 206, 250
    LightSlateGray         = 119, 136, 153
    LightSlateGrey         = 119, 136, 153
    LightSteelBlue         = 176, 196, 222
    LightYellow            = 255, 255, 224
    Lilac                  = 204, 153, 204
    Lime                   = 0, 255, 0
    LimeGreen              = 50, 205, 50
    Limerick               = 139, 190, 27
    Linen                  = 250, 240, 230
    Lipstick               = 159, 43, 104
    Liver                  = 83, 75, 79
    Lochinvar              = 86, 136, 125
    Lochmara               = 38, 97, 156
    Lola                   = 179, 158, 181
    LondonHue              = 170, 152, 169
    Lotus                  = 124, 72, 72
    LuckyPoint             = 29, 41, 81
    MacaroniAndCheese      = 255, 189, 136
    Madang                 = 193, 249, 162
    Madras                 = 81, 65, 0
    Magenta                = 255, 0, 255
    MagicMint              = 170, 240, 209
    Magnolia               = 248, 244, 255
    Mahogany               = 215, 59, 62
    Maire                  = 27, 24, 17
    Maize                  = 230, 190, 138
    Malachite              = 11, 218, 81
    Malibu                 = 93, 173, 236
    Malta                  = 169, 154, 134
    Manatee                = 140, 146, 172
    Mandalay               = 176, 121, 57
    MandarianOrange        = 146, 39, 36
    Mandy                  = 191, 79, 81
    Manhattan              = 229, 170, 112
    Mantis                 = 125, 194, 66
    Manz                   = 217, 230, 80
    MardiGras              = 48, 25, 52
    Mariner                = 57, 86, 156
    Maroon                 = 128, 0, 0
    Matterhorn             = 85, 85, 85
    Mauve                  = 244, 187, 255
    Mauvelous              = 255, 145, 175
    MauveTaupe             = 143, 89, 115
    MayaBlue               = 119, 181, 254
    McKenzie               = 129, 97, 60
    MediumAquamarine       = 102, 205, 170
    MediumBlue             = 0, 0, 205
    MediumCarmine          = 175, 64, 53
    MediumOrchid           = 186, 85, 211
    MediumPurple           = 147, 112, 219
    MediumRedViolet        = 189, 51, 164
    MediumSeaGreen         = 60, 179, 113
    MediumSlateBlue        = 123, 104, 238
    MediumSpringGreen      = 0, 250, 154
    MediumTurquoise        = 72, 209, 204
    MediumVioletRed        = 199, 21, 133
    MediumWood             = 166, 123, 91
    Melon                  = 253, 188, 180
    Merlot                 = 112, 54, 66
    MetallicGold           = 211, 175, 55
    Meteor                 = 184, 115, 51
    MidnightBlue           = 25, 25, 112
    MidnightExpress        = 0, 20, 64
    Mikado                 = 60, 52, 31
    MilanoRed              = 168, 55, 49
    Ming                   = 54, 116, 125
    MintCream              = 245, 255, 250
    MintGreen              = 152, 255, 152
    Mischka                = 168, 169, 173
    MistyRose              = 255, 228, 225
    Moccasin               = 255, 228, 181
    Mojo                   = 149, 69, 53
    MonaLisa               = 255, 153, 153
    Mongoose               = 179, 139, 109
    Montana                = 53, 56, 57
    MoodyBlue              = 116, 108, 192
    MoonYellow             = 245, 199, 26
    MossGreen              = 173, 223, 173
    MountainMeadow         = 28, 172, 120
    MountainMist           = 161, 157, 148
    MountbattenPink        = 153, 122, 141
    Mulberry               = 211, 65, 157
    Mustard                = 255, 219, 88
    Myrtle                 = 25, 89, 5
    MySin                  = 255, 179, 71
    NavajoWhite            = 255, 222, 173
    Navy                   = 0, 0, 128
    NavyBlue               = 2, 71, 254
    NeonCarrot             = 255, 153, 51
    NeonPink               = 255, 92, 205
    Nepal                  = 145, 163, 176
    Nero                   = 20, 20, 20
    NewMidnightBlue        = 0, 0, 156
    Niagara                = 58, 176, 158
    NightRider             = 59, 47, 47
    Nobel                  = 152, 152, 152
    Norway                 = 169, 186, 157
    Nugget                 = 183, 135, 39
    OceanGreen             = 95, 167, 120
    Ochre                  = 202, 115, 9
    OldCopper              = 111, 78, 55
    OldGold                = 207, 181, 59
    OldLace                = 253, 245, 230
    OldLavender            = 121, 104, 120
    OldRose                = 195, 33, 72
    Olive                  = 128, 128, 0
    OliveDrab              = 107, 142, 35
    OliveGreen             = 181, 179, 92
    Olivetone              = 110, 110, 48
    Olivine                = 154, 185, 115
    Onahau                 = 196, 216, 226
    Opal                   = 168, 195, 188
    Orange                 = 255, 165, 0
    OrangePeel             = 251, 153, 2
    OrangeRed              = 255, 69, 0
    Orchid                 = 218, 112, 214
    OuterSpace             = 45, 56, 58
    OutrageousOrange       = 254, 90, 29
    Oxley                  = 95, 167, 119
    PacificBlue            = 0, 136, 220
    Padua                  = 128, 193, 151
    PalatinatePurple       = 112, 41, 99
    PaleBrown              = 160, 120, 90
    PaleChestnut           = 221, 173, 175
    PaleCornflowerBlue     = 188, 212, 230
    PaleGoldenrod          = 238, 232, 170
    PaleGreen              = 152, 251, 152
    PaleMagenta            = 249, 132, 239
    PalePink               = 250, 218, 221
    PaleSlate              = 201, 192, 187
    PaleTaupe              = 188, 152, 126
    PaleTurquoise          = 175, 238, 238
    PaleVioletRed          = 219, 112, 147
    PalmLeaf               = 53, 66, 48
    Panache                = 233, 255, 219
    PapayaWhip             = 255, 239, 213
    ParisDaisy             = 255, 244, 79
    Parsley                = 48, 96, 48
    PastelGreen            = 119, 221, 119
    PattensBlue            = 219, 233, 244
    Peach                  = 255, 203, 164
    PeachOrange            = 255, 204, 153
    PeachPuff              = 255, 218, 185
    PeachYellow            = 250, 223, 173
    Pear                   = 209, 226, 49
    PearlLusta             = 234, 224, 200
    Pelorous               = 42, 143, 189
    Perano                 = 172, 172, 230
    Periwinkle             = 197, 203, 225
    PersianBlue            = 34, 67, 182
    PersianGreen           = 0, 166, 147
    PersianIndigo          = 51, 0, 102
    PersianPink            = 247, 127, 190
    PersianRed             = 192, 54, 44
    PersianRose            = 233, 54, 167
    Persimmon              = 236, 88, 0
    Peru                   = 205, 133, 63
    Pesto                  = 128, 117, 50
    PictonBlue             = 102, 153, 204
    PigmentGreen           = 0, 173, 67
    PigPink                = 255, 218, 233
    PineGreen              = 1, 121, 111
    PineTree               = 42, 47, 35
    Pink                   = 255, 192, 203
    PinkFlare              = 191, 175, 178
    PinkLace               = 240, 211, 220
    PinkSwan               = 179, 179, 179
    Plum                   = 221, 160, 221
    Pohutukawa             = 102, 12, 33
    PoloBlue               = 119, 158, 203
    Pompadour              = 129, 20, 83
    Portage                = 146, 161, 207
    PotPourri              = 241, 221, 207
    PottersClay            = 132, 86, 60
    PowderBlue             = 176, 224, 230
    Prim                   = 228, 196, 207
    PrussianBlue           = 0, 58, 108
    PsychedelicPurple      = 223, 0, 255
    Puce                   = 204, 136, 153
    Pueblo                 = 108, 46, 31
    PuertoRico             = 67, 179, 174
    Pumpkin                = 255, 99, 28
    Purple                 = 128, 0, 128
    PurpleMountainsMajesty = 150, 123, 182
    PurpleTaupe            = 93, 57, 84
    QuarterSpanishWhite    = 230, 224, 212
    Quartz                 = 220, 208, 255
    Quincy                 = 106, 84, 69
    RacingGreen            = 26, 36, 33
    RadicalRed             = 255, 32, 82
    Rajah                  = 251, 171, 96
    RawUmber               = 123, 63, 0
    RazzleDazzleRose       = 254, 78, 218
    Razzmatazz             = 215, 10, 83
    Red                    = 255, 0, 0
    RedBerry               = 132, 22, 23
    RedDamask              = 203, 109, 81
    RedOxide               = 99, 15, 15
    RedRobin               = 128, 64, 64
    RichBlue               = 84, 90, 167
    Riptide                = 141, 217, 204
    RobinsEggBlue          = 0, 204, 204
    RobRoy                 = 225, 169, 95
    RockSpray              = 171, 56, 31
    RomanCoffee            = 131, 105, 83
    RoseBud                = 246, 164, 148
    RoseBudCherry          = 135, 50, 96
    RoseTaupe              = 144, 93, 93
    RosyBrown              = 188, 143, 143
    Rouge                  = 176, 48, 96
    RoyalBlue              = 65, 105, 225
    RoyalHeath             = 168, 81, 110
    RoyalPurple            = 102, 51, 152
    Ruby                   = 215, 24, 104
    Russet                 = 128, 70, 27
    Rust                   = 192, 64, 0
    RusticRed              = 72, 6, 7
    Saddle                 = 99, 81, 71
    SaddleBrown            = 139, 69, 19
    SafetyOrange           = 255, 102, 0
    Saffron                = 244, 196, 48
    Sage                   = 143, 151, 121
    Sail                   = 161, 202, 241
    Salem                  = 0, 133, 67
    Salmon                 = 250, 128, 114
    SandyBeach             = 253, 213, 177
    SandyBrown             = 244, 164, 96
    Sangria                = 134, 1, 17
    SanguineBrown          = 115, 54, 53
    SanMarino              = 80, 114, 167
    SanteFe                = 175, 110, 77
    Sapphire               = 6, 42, 120
    Saratoga               = 84, 90, 44
    Scampi                 = 102, 102, 153
    Scarlet                = 255, 36, 0
    ScarletGum             = 67, 28, 83
    SchoolBusYellow        = 255, 216, 0
    Schooner               = 139, 134, 128
    ScreaminGreen          = 102, 255, 102
    Scrub                  = 59, 60, 54
    SeaBuckthorn           = 249, 146, 69
    SeaGreen               = 46, 139, 87
    Seagull                = 140, 190, 214
    SealBrown              = 61, 12, 2
    Seance                 = 96, 47, 107
    SeaPink                = 215, 131, 127
    SeaShell               = 255, 245, 238
    Selago                 = 250, 230, 250
    SelectiveYellow        = 242, 180, 0
    SemiSweetChocolate     = 107, 68, 35
    Sepia                  = 150, 90, 62
    Serenade               = 255, 233, 209
    Shadow                 = 133, 109, 77
    Shakespeare            = 114, 160, 193
    Shalimar               = 252, 255, 164
    Shamrock               = 68, 215, 168
    ShamrockGreen          = 0, 153, 102
    SherpaBlue             = 0, 75, 73
    SherwoodGreen          = 27, 77, 62
    Shilo                  = 222, 165, 164
    ShipCove               = 119, 139, 165
    Shocking               = 241, 156, 187
    ShockingPink           = 255, 29, 206
    ShuttleGrey            = 84, 98, 111
    Sidecar                = 238, 224, 177
    Sienna                 = 160, 82, 45
    Silk                   = 190, 164, 147
    Silver                 = 192, 192, 192
    SilverChalice          = 175, 177, 174
    SilverTree             = 102, 201, 146
    SkyBlue                = 135, 206, 235
    SlateBlue              = 106, 90, 205
    SlateGray              = 112, 128, 144
    SlateGrey              = 112, 128, 144
    Smalt                  = 0, 48, 143
    SmaltBlue              = 74, 100, 108
    Snow                   = 255, 250, 250
    SoftAmber              = 209, 190, 168
    Solitude               = 235, 236, 240
    Sorbus                 = 233, 105, 44
    Spectra                = 53, 101, 77
    SpicyMix               = 136, 101, 78
    Spray                  = 126, 212, 230
    SpringBud              = 150, 255, 0
    SpringGreen            = 0, 255, 127
    SpringSun              = 236, 235, 189
    SpunPearl              = 170, 169, 173
    Stack                  = 130, 142, 132
    SteelBlue              = 70, 130, 180
    Stiletto               = 137, 63, 69
    Strikemaster           = 145, 92, 131
    StTropaz               = 50, 82, 123
    Studio                 = 115, 79, 150
    Sulu                   = 201, 220, 135
    SummerSky              = 33, 171, 205
    Sun                    = 237, 135, 45
    Sundance               = 197, 179, 88
    Sunflower              = 228, 208, 10
    Sunglow                = 255, 204, 51
    SunsetOrange           = 253, 82, 64
    SurfieGreen            = 0, 116, 116
    Sushi                  = 111, 153, 64
    SuvaGrey               = 140, 140, 140
    Swamp                  = 35, 43, 43
    SweetCorn              = 253, 219, 109
    SweetPink              = 243, 153, 152
    Tacao                  = 236, 177, 118
    TahitiGold             = 235, 97, 35
    Tan                    = 210, 180, 140
    Tangaroa               = 0, 28, 61
    Tangerine              = 228, 132, 0
    TangerineYellow        = 253, 204, 13
    Tapestry               = 183, 110, 121
    Taupe                  = 72, 60, 50
    TaupeGrey              = 139, 133, 137
    TawnyPort              = 102, 66, 77
    TaxBreak               = 79, 102, 106
    TeaGreen               = 208, 240, 192
    Teak                   = 176, 141, 87
    Teal                   = 0, 128, 128
    TeaRose                = 255, 133, 207
    Temptress              = 60, 20, 33
    Tenne                  = 200, 101, 0
    TerraCotta             = 226, 114, 91
    Thistle                = 216, 191, 216
    TickleMePink           = 245, 111, 161
    Tidal                  = 232, 244, 140
    TitanWhite             = 214, 202, 221
    Toast                  = 165, 113, 100
    Tomato                 = 255, 99, 71
    TorchRed               = 255, 3, 62
    ToryBlue               = 54, 81, 148
    Tradewind              = 110, 174, 161
    TrendyPink             = 133, 96, 136
    TropicalRainForest     = 0, 127, 102
    TrueV                  = 139, 114, 190
    TulipTree              = 229, 183, 59
    Tumbleweed             = 222, 170, 136
    Turbo                  = 255, 195, 36
    TurkishRose            = 152, 119, 123
    Turquoise              = 64, 224, 208
    TurquoiseBlue          = 118, 215, 234
    Tuscany                = 175, 89, 62
    TwilightBlue           = 253, 255, 245
    Twine                  = 186, 135, 89
    TyrianPurple           = 102, 2, 60
    Ultramarine            = 10, 17, 149
    UltraPink              = 255, 111, 255
    Valencia               = 222, 82, 70
    VanCleef               = 84, 61, 55
    VanillaIce             = 229, 204, 201
    VenetianRed            = 209, 0, 28
    Venus                  = 138, 127, 128
    Vermilion              = 251, 79, 20
    VeryLightGrey          = 207, 207, 207
    VidaLoca               = 94, 140, 49
    Viking                 = 71, 171, 204
    Viola                  = 180, 131, 149
    ViolentViolet          = 50, 23, 77
    Violet                 = 238, 130, 238
    VioletRed              = 255, 57, 136
    Viridian               = 64, 130, 109
    VistaBlue              = 159, 226, 191
    VividViolet            = 127, 62, 152
    WaikawaGrey            = 83, 104, 149
    Wasabi                 = 150, 165, 60
    Watercourse            = 0, 106, 78
    Wedgewood              = 67, 107, 149
    WellRead               = 147, 61, 65
    Wewak                  = 255, 152, 153
    Wheat                  = 245, 222, 179
    Whiskey                = 217, 154, 108
    WhiskeySour            = 217, 144, 88
    White                  = 255, 255, 255
    WhiteSmoke             = 245, 245, 245
    WildRice               = 228, 217, 111
    WildSand               = 229, 228, 226
    WildStrawberry         = 252, 65, 154
    WildWatermelon         = 255, 84, 112
    WildWillow             = 172, 191, 96
    Windsor                = 76, 40, 130
    Wisteria               = 191, 148, 228
    Wistful                = 162, 162, 208
    Yellow                 = 255, 255, 0
    YellowGreen            = 154, 205, 50
    YellowOrange           = 255, 174, 66
    YourPink               = 244, 194, 194
}
$script:ErrorActionPreference = 'SilentlyContinue'
Add-Type -TypeDefinition @"
public enum RGBColors {
    None,
    Black,
    Navy,
    DarkBlue,
    MediumBlue,
    Blue,
    DarkGreen,
    Green,
    Teal,
    DarkCyan,
    DeepSkyBlue,
    DarkTurquoise,
    MediumSpringGreen,
    Lime,
    SpringGreen,
    Aqua,
    Cyan,
    MidnightBlue,
    DodgerBlue,
    LightSeaGreen,
    ForestGreen,
    SeaGreen,
    DarkSlateGray,
    DarkSlateGrey,
    LimeGreen,
    MediumSeaGreen,
    Turquoise,
    RoyalBlue,
    SteelBlue,
    DarkSlateBlue,
    MediumTurquoise,
    Indigo,
    DarkOliveGreen,
    CadetBlue,
    CornflowerBlue,
    MediumAquamarine,
    DimGray,
    DimGrey,
    SlateBlue,
    OliveDrab,
    SlateGray,
    SlateGrey,
    LightSlateGray,
    LightSlateGrey,
    MediumSlateBlue,
    LawnGreen,
    Chartreuse,
    Aquamarine,
    Maroon,
    Purple,
    Olive,
    Grey,
    Gray,
    //Grey,
    SkyBlue,
    LightSkyBlue,
    BlueViolet,
    DarkRed,
    DarkMagenta,
    SaddleBrown,
    DarkSeaGreen,
    LightGreen,
    MediumPurple,
    DarkViolet,
    PaleGreen,
    DarkOrchid,
    YellowGreen,
    Sienna,
    Brown,
    DarkGray,
    DarkGrey,
    LightBlue,
    GreenYellow,
    PaleTurquoise,
    LightSteelBlue,
    PowderBlue,
    FireBrick,
    DarkGoldenrod,
    MediumOrchid,
    RosyBrown,
    DarkKhaki,
    Silver,
    MediumVioletRed,
    IndianRed,
    Peru,
    Chocolate,
    Tan,
    LightGray,
    LightGrey,
    Thistle,
    Orchid,
    Goldenrod,
    PaleVioletRed,
    Crimson,
    Gainsboro,
    Plum,
    BurlyWood,
    LightCyan,
    Lavender,
    DarkSalmon,
    Violet,
    PaleGoldenrod,
    LightCoral,
    Khaki,
    AliceBlue,
    Honeydew,
    Azure,
    SandyBrown,
    Wheat,
    Beige,
    WhiteSmoke,
    MintCream,
    GhostWhite,
    Salmon,
    AntiqueWhite,
    Linen,
    LightGoldenrodYellow,
    OldLace,
    Red,
    Fuchsia,
    Magenta,
    DeepPink,
    OrangeRed,
    Tomato,
    HotPink,
    Coral,
    DarkOrange,
    LightSalmon,
    Orange,
    LightPink,
    Pink,
    Gold,
    PeachPuff,
    NavajoWhite,
    Moccasin,
    Bisque,
    MistyRose,
    BlanchedAlmond,
    PapayaWhip,
    LavenderBlush,
    Seashell,
    Cornsilk,
    LemonChiffon,
    FloralWhite,
    Snow,
    Yellow,
    LightYellow,
    Ivory,
    White
}
"@

function Convert-Color {
    <#
    .Synopsis
    This color converter gives you the hexadecimal values of your RGB colors and vice versa (RGB to HEX)
    .Description
    This color converter gives you the hexadecimal values of your RGB colors and vice versa (RGB to HEX). Use it to convert your colors and prepare your graphics and HTML web pages.
    .Parameter RBG
    Enter the Red Green Blue value comma separated. Red: 51 Green: 51 Blue: 204 for example needs to be entered as 51,51,204
    .Parameter HEX
    Enter the Hex value to be converted. Do not use the '#' symbol. (Ex: 3333CC converts to Red: 51 Green: 51 Blue: 204)
    .Example
    .\convert-color -hex FFFFFF
    Converts hex value FFFFFF to RGB

    .Example
    .\convert-color -RGB 123,200,255
    Converts Red = 123 Green = 200 Blue = 255 to Hex value

    #>
    param(
        [Parameter(ParameterSetName = "RGB", Position = 0)]
        [ValidateScript( {$_ -match '^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$'})]
        $RGB,
        [Parameter(ParameterSetName = "HEX", Position = 0)]
        [ValidateScript( {$_ -match '[A-Fa-f0-9]{6}'})]
        [string]
        $HEX
    )
    switch ($PsCmdlet.ParameterSetName) {
        "RGB" {
            if ($null -eq $RGB[2]) {
                Write-error "Value missing. Please enter all three values seperated by comma."
            }
            $red = [convert]::Tostring($RGB[0], 16)
            $green = [convert]::Tostring($RGB[1], 16)
            $blue = [convert]::Tostring($RGB[2], 16)
            if ($red.Length -eq 1) {
                $red = '0' + $red
            }
            if ($green.Length -eq 1) {
                $green = '0' + $green
            }
            if ($blue.Length -eq 1) {
                $blue = '0' + $blue
            }
            Write-Output $red$green$blue
        }
        "HEX" {
            $red = $HEX.Remove(2, 4)
            $Green = $HEX.Remove(4, 2)
            $Green = $Green.remove(0, 2)
            $Blue = $hex.Remove(0, 4)
            $Red = [convert]::ToInt32($red, 16)
            $Green = [convert]::ToInt32($green, 16)
            $Blue = [convert]::ToInt32($blue, 16)
            Write-Output $red, $Green, $blue
        }
    }
}