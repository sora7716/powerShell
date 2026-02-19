$appIds = @(
  "Google.Chrome",
  "SlackTechnologies.Slack",
  "Zoom.Zoom",
  "Microsoft.VisualStudioCode",
  "Valve.Steam",
  "Unity.UnityHub",
  "BlenderFoundation.Blender",
  "Microsoft.VisualStudio.2022.Community"
)

foreach ($id in $appIds) {
  Write-Host "更新状況を確認: $id"
  winget list -e --id $id
}
