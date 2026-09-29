# Security and privacy

This is an educational local administration tool. Review code and configuration before execution. Use a disposable Windows VM for package installation tests.

## Sensitive output

Live reports include machine names, operating system details and possible exception messages. Journals include local paths and installer errors. The asset inventory can contain employee information when populated with real records. `.gitignore` prevents common accidental additions but is not a data-loss-prevention system.

Keep live data outside a public repository, restrict directory permissions and redact before sharing. The tool does not upload data, collect credentials or encrypt local output.

## Configuration trust

Only run configurations you reviewed. Exact WinGet package IDs reduce ambiguity but do not certify package suitability. Agreement acceptance and package installation are explicit opt-ins. Native operations are invoked without a shell. There is no remote management endpoint.

Provisioning refuses existing symlinks/junctions in planned paths. It does not defend against an attacker who can concurrently alter the same filesystem. Run from a directory controlled by the operator. Do not expose these scripts as a privileged web service.

## Reporting a vulnerability

After a GitHub repository is created, enable private vulnerability reporting before inviting security reports. Until a private reporting channel exists, do not open public issues containing exploitable details or sensitive data. No maintainer contact address has been invented for this starter repository.
