# DBMS System with Bash Scripts

## Description
This project is a simple Database Management System (DBMS) implemented using Bash scripts. It allows users to create, manage, and manipulate databases and tables directly from the command line without the need for an external database engine.

## Features
- Create and delete databases
- Create, list, and delete tables within a database
- Insert, update, and delete records in tables
- Search for specific records
- Display table data
- Validate input data types

## Installation
No special installation is required. Ensure that you have a Linux or macOS system with Bash installed.

## Usage
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dbms-bash.git
   cd dbms-bash
   ```
2. Run the main script:
   ```bash
   ./dbms.sh
   ```
3. Follow the on-screen instructions to create and manage your databases and tables.

## Folder Structure
```
/dbms-bash
├── dbms.sh         # Main script to interact with the DBMS
├── functions.sh    # Contains reusable functions
├── databases/      # Stores database files
├── README.md       # Project documentation
```

## Example Commands
- Create a new database:
  ```bash
  ./dbms.sh create_database my_database
  ```
- Create a table:
  ```bash
  ./dbms.sh create_table my_database my_table
  ```
- Insert data into a table:
  ```bash
  ./dbms.sh insert my_database my_table "value1" "value2"
  ```

## Contributing
If you'd like to contribute, feel free to fork the repository and submit a pull request with improvements or bug fixes.

## License
This project is licensed under the MIT License.

