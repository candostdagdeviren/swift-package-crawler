
/*
 Main:
 - show simple index file, show link to the github repo for documentation of the API
 
 Utils:
 - endpoint for getting a project's Package.swift: /packages/github/USER/NAME/manifest
 - endpoint for getting a project's Package.swift in JSON format: /packages/github/USER/NAME/manifest/json
 
 Package Info:
 - endpoint for getting project's direct dependencies /packages/github/USER/NAME/stats/dependencies/direct
 - endpoint for getting project's transitive dependencies /packages/github/USER/NAME/stats/dependencies/transitive
 
 Stats:
 - endpoint for getting project's direct dependees /packages/github/USER/NAME/stats/dependees/direct
 - endpoint for getting project's transitive dependees /packages/github/USER/NAME/stats/dependees/transitive
 - endpoint for getting user's direct dependees /packages/github/USER/stats/dependees/direct
 - endpoint for getting user's transitive dependees /packages/github/USER/stats/dependees/transitive
 
 Data queries:
 - endpoint for getting the list of GitHub project names /data/github/names (paging API)
 - endpoint for downloading the full dataset of Package.swift files /data/manifests/download
 - endpoint for downloading the full dataset of Package.swift files as JSON /download/manifests/download?format=json
 */
