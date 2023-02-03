# redshift-roles
Scripts, SQL, and Stored Procedures that are useful in using and adopting the use of using ROLE for security access in Redshift.

## Contents
- pr_migrate_groups_to_roles.sql - Stored procedure that creates roles based on the existing groups and performs the grants needed to replace groups in favor of roles.
  - Parameter: dryrun boolean
  true: indicates that the stored procedure will NOT create any roles or perform any grants. Instead, the procedure will only output through RAISE INFO, the commands that will be executed when dryrun is false.
  false: indicates that the stored proceudre WILL create roles and perform grants. The procedure also outputs the commands being executed with RAISE INFO.  

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.
