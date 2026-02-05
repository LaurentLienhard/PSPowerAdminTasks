# Module Deployment Guide

Ce guide explique comment déployer le module `PSPowerAdminTasks` sur des serveurs distants.

## 📋 Prérequis

- PowerShell Remoting activé sur les serveurs cibles
- Accès WinRM aux serveurs
- Permissions d'administrateur sur les serveurs cibles

## 🚀 Méthodes de déploiement

### Méthode 1: Utiliser le contexte utilisateur actuel (Plus simple)

Si vous avez les permissions d'admin sur les serveurs:

```powershell
./build.ps1 -Tasks deploy
```

### Méthode 2: Sauvegarder les credentials (Recommandé)

**Étape 1: Sauvegarder les credentials**
```powershell
./build.ps1 -Tasks Save_Deploy_Credentials
```

Cela crée un fichier `deploy-credentials.xml` chiffré dans `.build/config/`

**Étape 2: Déployer avec les credentials sauvegardés**
```powershell
./build.ps1 -Tasks deploy
```

Ou avec une tâche spécifique:
```powershell
./build.ps1 -Tasks Deploy_Module_Custom -ComputerName 'serveur.contoso.com'
```

### Méthode 3: Passer les credentials en ligne de commande

```powershell
$cred = Get-Credential
./build.ps1 -Tasks deploy -Credential $cred
```

Ou pour un serveur spécifique:
```powershell
$cred = Get-Credential
./build.ps1 -Tasks Deploy_Module_Custom -ComputerName 'serveur.contoso.com' -Credential $cred
```

### Méthode 4: Utiliser une variable d'environnement

```powershell
$env:DEPLOY_CREDENTIAL_PATH = 'C:\path\to\saved-credentials.xml'
./build.ps1 -Tasks deploy
```

## 📝 Configuration des serveurs

Éditez le fichier `.build/tasks/Deploy-Module.build.ps1` et modifiez le tableau `$servers`:

```powershell
$servers = @(
    @{
        ComputerName = 'server1.contoso.com'
        DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\'
    }
    @{
        ComputerName = 'server2.contoso.com'
        DestinationPath = 'C:\Program Files\WindowsPowerShell\Modules\'
    }
)
```

## 🎯 Exemples de déploiement

### Déployer sur tous les serveurs configurés
```powershell
./build.ps1 -Tasks deploy
```

### Déployer sur un serveur spécifique
```powershell
./build.ps1 -Tasks Deploy_Module_Custom -ComputerName 'server1.contoso.com'
```

### Déployer avec un chemin personnalisé
```powershell
./build.ps1 -Tasks Deploy_Module_Custom `
    -ComputerName 'server.contoso.com' `
    -DestinationPath 'D:\PSModules\'
```

### Déployer avec credentials personnalisés
```powershell
$cred = Get-Credential -UserName 'contoso\admin'
./build.ps1 -Tasks Deploy_Module_Custom `
    -ComputerName 'server.contoso.com' `
    -Credential $cred
```

## 🔐 Gestion des credentials

### Voir l'aide des credentials
```powershell
./build.ps1 -Tasks Credential_Help
```

### Charger les credentials sauvegardés
```powershell
./build.ps1 -Tasks Load_Deploy_Credentials
```

### Effacer les credentials sauvegardés
```powershell
./build.ps1 -Tasks Clear_Deploy_Credentials
```

## ✅ Vérification du déploiement

La tâche de déploiement vérifie automatiquement que le module a été correctement copié sur le serveur distant.

Vous verrez un message comme:
```
Module verified on server1.contoso.com: v0.0.1
```

## 🛠️ Dépannage

### Erreur: "Failed to deploy to server.contoso.com: Access Denied"

- Vérifiez que vous avez les bonnes permissions
- Vérifiez que le serveur accepte les connexions PowerShell Remoting
- Vérifiez que le credentials est correct

### Erreur: "Module path not found"

Compilez d'abord le module:
```powershell
./build.ps1 -Tasks build
```

Puis essayez le déploiement:
```powershell
./build.ps1 -Tasks deploy
```

### Erreur: "WinRM is not configured on the remote computer"

Sur le serveur cible, exécutez:
```powershell
Enable-PSRemoting -Force
```

## 📚 Tâches disponibles

| Tâche | Description |
|-------|-------------|
| `deploy` | Compile et déploie sur tous les serveurs configurés |
| `Deploy_Module` | Déploie sur tous les serveurs (avec credentials) |
| `Deploy_Module_Custom` | Déploie sur un serveur spécifique |
| `Save_Deploy_Credentials` | Sauvegarde les credentials de manière sécurisée |
| `Load_Deploy_Credentials` | Charge les credentials sauvegardés |
| `Clear_Deploy_Credentials` | Efface les credentials sauvegardés |
| `Credential_Help` | Affiche l'aide sur la gestion des credentials |

## 🔗 Liens utiles

- [PowerShell Remoting Documentation](https://docs.microsoft.com/powershell/scripting/learn/remoting/running-remote-commands)
- [Get-PSSession](https://docs.microsoft.com/powershell/module/microsoft.powershell.core/get-pssession)
- [Copy-Item with remote sessions](https://docs.microsoft.com/powershell/module/microsoft.powershell.management/copy-item)
