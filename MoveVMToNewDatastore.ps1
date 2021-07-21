Import-Module -Name VMware.PowerCLI

# Connexion au vCenter : -Server vcenter.groupeomicrone.com -user "toto" -Password "tata"
Connect-VIServer -Server x.x.x.x -User "...." -Password "...."

# Liste les vms actives qui sont sur le ou les datastores d'origine
$vmlist = get-vm -Datastore <# DATASTORE_ORIGINE #> | Where-Object {$_.PowerState -ne 'PoweredOff'} | Select-Object Name -Unique 

####
#   Logs 
#   Path : .\Log.txt
####
$dir = Get-Location
$Logfile = $dir.Path + "\Log.txt"
Start-Transcript -Path $Logfile  

# Traitement des vms qui ont été récupérées 
foreach ($vm in $vmlist)
{
    
    $vm_name = $vm.Name
    
    # Extinction de la vm en cours de traitement 
    Try
    {
        $shutdown_rc = 0 # Code retour shutdown 
        Stop-VMGuest -VM $vm_name -Confirm:$false -ErrorAction Stop
    }
    Catch
    { 
        # Echec de l'extinction de l'hôte -
        Write-Output "Guest Shutdown Failed" 
        $shutdown_rc = 1
    }

    If ($shutdown_rc -eq 1 )
    {
        Try 
        {
            # Nouvelle tentative en éteignant directement la machine virtuelle 
            $shutdown_rc = 0 
            Stop-VM -VM $vm_name -Confirm:$false -ErrorAction Stop 
        }
        Catch
        { 
            Write-Output "Host Shutdown Failed" 
            $shutdown_rc = 1
        }
    }

    # Si le code retour d'extinction est égale à 0 on lance le déplacement de la VM 
    If( $shutdown_rc -ne 1 )
    {
        # on vérifie l'état et on boucle tant que la VM n'est pas éteinte 
        $state = Get-VM -Name $vm_name | Select-Object PowerState 
        while ($state.PowerState -ne "PoweredOff") 
        {
            Write-Output("State : "+$state.PowerState+" Attente extinction VM")
            Start-Sleep 4   
            $state = Get-VM -Name $vm_name | Select-Object PowerState
        }
        
        # Déplacement de la VM vers le nouveau datastore 
        Move-VM -VM $vm_name -Datastore <# DATASTORE_DST #> 

        # Redémarrage ; On attend que la vm redémarre 
        Start-VM -VM $vm_name 
        while ($state.PowerState -ne "PoweredOn") 
        {
            Write-Output("State : "+$state.PowerState+" - Attente allumage VM")
            Start-Sleep 4   
            $state = Get-VM -Name $vm_name | Select-Object PowerState
        }

        # Fin 
        Write-Output("Over : "+$vm_name+" - "+$state.PowerState) 
    }
}

# Fermeture logs 
Stop-Transcript
