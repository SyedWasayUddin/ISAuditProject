# ISAuditProject
Active Directory Recon
Active_Directory_Recon is a tool which extracts and combines various artefacts (as highlighted below) out of an AD environment. The information can be presented in a specially formatted Microsoft Excel report that includes summary views with metrics to facilitate analysis and provide a holistic picture of the current state of the target AD environment.

The tool is useful to various classes of security professionals like auditors, DFIR, students, administrators, etc. It can also be an invaluable post-exploitation tool for a penetration tester.

It can be run from any workstation that is connected to the environment, even hosts that are not domain members. Furthermore, the tool can be executed in the context of a non-privileged (i.e. standard domain user) account. Fine Grained Password Policy, LAPS and BitLocker may require Privileged user accounts. The tool will use Microsoft Remote Server Administration Tools (RSAT) if available, otherwise it will communicate with the Domain Controller using LDAP.

The following information is gathered by the tool:

* Forest;
* Domain;
* Trusts;
* Sites;
* Subnets;
* Schema History;
* Default and Fine Grained Password Policy (if implemented);
* Domain Controllers, SMB versions, whether SMB Signing is supported and FSMO roles;
* Users and their attributes;
* Service Principal Names (SPNs);
* Groups, memberships and changes;
* Organizational Units (OUs);
* GroupPolicy objects and gPLink details;
* DNS Zones and Records;
* Printers;
* Computers and their attributes;
* PasswordAttributes (Experimental);
* LAPS passwords (if implemented);
* BitLocker Recovery Keys (if implemented);
* ACLs (DACLs and SACLs) for the Domain, OUs, Root Containers, GPO, Users, Computers and Groups objects (not included in the default collection method);
* GPOReport (requires RSAT);
* Kerberoast (not included in the default collection method); and
* Domain accounts used for service accounts (requires privileged account and not included in the default collection method).