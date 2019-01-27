$csvpath = "C:\Users.csv"
Import-Module Add-Labvm
Import-Module New-Natswitch

#skapa VM och switch
New-NATSwitch -Name "Switch01" -IPAddress '172.16.0.10' #Skapar en NATSwitch
New-LabVM -VMName "DC1" -VMIP '172.16.0.11' -GWIP '172.16.0.10' -Diskpath "C:\DC1\" -ParentDisk "C:\parent.vhdx" -DNSIP '127.0.0.1' -VMSwitch "Switch01"
New-LabVM -VMName "Serv1" -VMIP '172.16.0.13' -GWIP '172.16.0.10' -Diskpath "C:\Serv1\" -ParentDisk "C:\parent.vhdx" -DNSIP '172.16.0.11' -VMSwitch "Switch01"
New-LabVM -VMName "Serv2" -VMIP '172.16.0.14' -GWIP '172.16.0.10' -Diskpath "C:\Serv2\" -ParentDisk "C:\parent.vhdx" -DNSIP '172.16.0.11' -VMSwitch "Switch01"

#installerar ny domän
Enter-PSSession -VMName DC1
Import-Module Servermanager
Install-Module addsdeployment
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath 'C:\Windows\NTDS' -DomainMode 'Win2012R2' -DomainName 'chrille.local' -DomainNetbiosName 'chrille' -ForestMode 'Win2012R2' -InstallDns:$true -LogPath 'C:\Windows\NTDS' -NoRebootOnCompletion:$false -SysvolPath 'C:\Windows\SYSVOL' -Force:$true
Install-WindowsFeature -Name RSAT
Exit-PSSession

#joinar servrar på domänen
Enter-PSSession -VMName Serv1
Add-Computer -DomainName 'chrille.local'
Exit-PSSession
Enter-PSSession -VMName Serv2
Add-Computer -DomainName 'chrille.local'
Exit-PSSession

$users = Import-CSV -Path $csvpath
#importerar användare från csv-fil, skapar shares
foreach ($user in $users){
    Invoke-Command -VMName DC1 -ScriptBlock {
        $FN = $user.FirstName.Split(0,3)
        $LN = $user.LastName.Split(0,3)
        $username = $Fname + $Lname
        New-ADuser -Name $username -DisplayName $username -SamAccountName  $username
        New-Item -Path C:\share\$username\ -ItemType Directory
        New-SmbShare -Name $username -Path C:\share\$username\
        Grant-SmbShareAccess -Name $username -AccountName $username -AccessRight full 
    }
}
#skapar en share
Invoke-Command -VMName DC1 -ScriptBlock {
    New-Item -Path C:\share\sharedtoall
    New-SmbShare -Name sharedtoall -path C:\share\sharedtoall
    Grant-SmbShareAccess -name sharedtoall -AccountName 'Alla' -AccessRight Read
}