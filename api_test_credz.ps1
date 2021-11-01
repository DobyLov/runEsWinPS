$global:EsPort ="9200"
$KiPort ="5601"
$global:KibanaUrl ="http://localhost:$KiPort"
$global:KibanaFilePath ='C:\estack\kibana\bin\kibana.bat'

function Nodes_Conf_Loader(){
    $global:nodes_json = Get-Content '.\nodes.json' | ConvertFrom-Json
}

function Start_Number_Of_Nodes(){
    $MaxNumberOfNodes = $nodes_json.nodes.Length
    try {
        [int]$global:DesiredNodesNumber = Read-Host "How many nodes to start[$MaxNumberOfNodes max]"
    } catch {
        Write-Host "=> Only Numbers please, retry or 0 to exit"
        Start_Number_Of_Nodes
    }
    If ($DesiredNodesNumber -le 0 -Or $DesiredNodesNumber -gt $MaxNumberOfNodes){
        if ($DesiredNodesNumber -eq 0) {
            Write-Host "Exit script" 
            exit
        }
        Write-Host "=>  Possible choices are 0-$MaxNumberOfNodes, please retry 0 to exit script"
        Start_Number_Of_Nodes
    }
    # exec credz constructor
    Credz_Constructor
    for ($Nodes=0; $Nodes -lt $DesiredNodesNumber; $Nodes++){
        Write-host "Test api node: " $nodes_json.nodes[$Nodes].node_name
        Write-host "Test api ip:" $nodes_json.nodes[$Nodes].adress_ip
        EsApiTestConnection $nodes_json.nodes[$Nodes].adress_ip $nodes_json.nodes[$Nodes].instance_path
        }
}

# Credz section
function global:Credz_Constructor(){
    $global:EsUser = Read-Host "Enter elasticsearch user[elastic]"
    If ($null -ne $EsUser) {$EsUser = 'elastic'}
        $global:promptPassword = Read-Host 'Enter elasticsearch password ?' -AsSecureString
    If ($promptPassword.Length -eq 0) {
        #$promptPassword = ConvertTo-SecureString "" -AsPlainText -Force
    }
    $global:Credz = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($EsUser+":"+(PasswordDecoder($promptPassword))))
}

function PasswordDecoder{
    param($pwdToDecode)
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwdToDecode))
}

function global:EsApiTestConnection(){
    param(
        [Parameter(Mandatory=$true, Position=0)] $Address_Ip,
        [Parameter(Mandatory=$true, Position=1)] $Instance_Path
    )
    $EsUri="http://" + $Address_Ip + ":" + $EsPort
    try {
        $Params = @{ 
            Authorization = "Basic " + $Credz
        }
        Write-host $Params
        $Response = Invoke-WebRequest -Uri $EsUri -UseBasicParsing -Headers $Params -Verbose -TimeoutSec 3 -ErrorVariable RespErr
        Write-host $Response
        Write-Host "status.code =>" $Response.statuscode
        if ( $Response.statuscode -eq '200' ) {    
            Write-Host "Node is up no need to start it !" 
        } 
    } catch {
        $ErrorMsgToJson = $error[0].ErrorDetails.Message
        if ($Null -ne $ErrorMsgToJson -And $ErrorMsgToJson.Contains("401") ){
            Write-Host "credentials problems"
            Credz_Constructor
            EsApiConnection
        } else {
            Write-Host "Node is down, start instance"
            EsNodeLuncher $Instance_Path
        } 
    }
}

function EsNodeLuncher{
    param (
        [string] $Instance_Path
    )
    Write-host "Run node:"
    Write-host  $Instance_Path"\elasticsearch.bat"
    
    if ( (Test-Path -Path $Instance_Path"\elasticsearch.bat" -PathType Leaf) ) {
        try{
            $Complete_Path = "cmd /c start powershell -noexit -Command `"$Instance_Path\elasticsearch.bat`""
            invoke-expression $Complete_Path
        } catch {
            Write-Host "Not able to exec "$Complete_Path
        }
    } else {
        Write-Host $Instance_Path" Not found"
    }
}


function check_kibana_api(){
    try{
        Write-Host "Check kibana is up"
        $RespKib = Invoke-WebRequest -Uri $KibanaUrl"/status" -UseBasicParsing
        if ($RespKib -eq 200){
            write-host $RespKib.statuscode
        }
        Write-host "Kibana is up, no need to start it"
    } catch {
       write-host "Starting kibana"
       run_kibana
    }
}

function run_kibana(){
    if( (Test-Path -Path $KibanaFilePath -PathType Leaf) ){
        try{
            #$Complete_Path = "cmd /c start powershell -noexit -Command `"C:\estack\kibana\bin\kibana.bat`""
            $Complete_Path = "cmd /c start powershell -noexit -Command $KibanaFilePath"
            invoke-expression $Complete_Path
        } catch {
            Write-Host "Unable to exec "$Complete_Path
        }
    } else {
        Write-Host $KibanaFilePa" not found"
    }
    
}


function open_WebBrowser(){
    param (
        [string]$UrlToOpen
    )
    try{
        [system.Diagnostics.Process]::Start("msedge",$UrlToOpen)
    }catch {
        Write-host "unable to open url:" $UrlToOpen
    }
}

# Run script
Nodes_Conf_Loader
#Start_Number_Of_Nodes
check_kibana_api
open_WebBrowser $KibanaUrl



