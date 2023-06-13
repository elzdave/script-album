# MariaDB/MySQL Access Password Reset Script

This folder contains 2 scripts that serve different purposes:

- `mrrootpwd` : root password reset script, require **administrative privilege**

  Usage :

  ```bash
  chmod 750 mrrootpwd
  sudo bash mrrootpwd [your-new-root-password]
  ```

  Example :

  ```bash
  chmod 750 mrrootpwd
  sudo bash mrrootpwd sTr0n9p45sw0Rd
  ```

- `mruserpwd` : normal user password reset script, using normal privilege but require **`root` password** to proceed password reset

  Usage :

  ```bash
  chmod 750 mruserpwd
  bash mruserpwd
  ```

  Example :

  ```bash
  chmod 750 mruserpwd
  bash mruserpwd
  ```

## Database Version Support :

- MariaDB 10.0+
- MySQL 5.5+

## Operating System Support :

- Ubuntu
- Fedora
