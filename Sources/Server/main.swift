
//TODO: this will launch the server
/*
Main:
- show simple index file, show link to the github repo for documentation of the API

Utils:
- endpoint for getting a project's Package.swift: /packages/github/USER/NAME/manifest
- endpoint for getting a project's Package.swift in JSON format: /packages/github/USER/NAME/manifest/json

Stats:
- endpoint for getting project's direct dependencies /packages/github/USER/NAME/stats/dependencies/direct
- endpoint for getting project's transitive dependencies /packages/github/USER/NAME/stats/dependencies/transitive
- endpoint for getting user's direct dependencies /packages/github/USER/stats/dependencies/direct
- endpoint for getting user's transitive dependencies /packages/github/USER/stats/dependencies/transitive

Data queries:
- endpoint for getting the list of GitHub project names /data/github/names (paging API)
- endpoint for downloading the full dataset of Package.swift files /data/manifests/download
- endpoint for downloading the full dataset of Package.swift files as JSON /download/manifests/download?format=json
*/
