# 05. AWS DynamoDB & RDS — Database Services

This guide provides an architectural comparison and deep dive into two flagship AWS database offerings: **Amazon DynamoDB** (Fully Managed NoSQL) and **Amazon RDS** (Managed Relational Database Service).

---

## 1. Amazon DynamoDB (NoSQL Database)

### 1.1 What is DynamoDB?
**Amazon DynamoDB** is a fully managed, serverless, key-value and document NoSQL database designed to deliver single-digit millisecond latency at any scale. It features built-in security, continuous backups, automated multi-region replication, and in-memory caching via DynamoDB Accelerator (DAX).

### 1.2 Core DynamoDB Concepts
- **NoSQL**: Schema-less data model where each item can possess distinct attributes (except primary key components). No complex table joins; designed for horizontal scaling across distributed partitions.
- **Tables**: The collection of items (equivalent to a table in relational databases).
- **Items**: A group of attributes uniquely identifiable among all other items (equivalent to a row). Item size limit is 400 KB.
- **Attributes**: Fundamental data elements (equivalent to a field or column, e.g., strings, numbers, binary, sets, maps, lists).

### 1.3 Primary Keys in DynamoDB
DynamoDB uses primary keys to uniquely identify each item and distribute data across physical storage partitions:

1. **Simple Primary Key (Partition Key only)**:
   - Also called **Hash Key**.
   - DynamoDB hashes the partition key value to determine the physical partition where the item is stored.
   - Every item must have a unique partition key value (e.g., `UserID: 101`).

2. **Composite Primary Key (Partition Key + Sort Key)**:
   - **Partition Key (Hash Key)** + **Sort Key (Range Key)**.
   - Multiple items can share the same partition key as long as their sort keys differ.
   - Items with the same partition key are stored together in physical partition order sorted by the sort key.
   - *Example:* Partition Key = `CustomerID`, Sort Key = `OrderTimestamp`.

### 1.4 DynamoDB Common Use Cases
- High-velocity IoT sensor telemetry and event tracking.
- Gaming leaderboards, player profiles, and session state caching.
- E-commerce shopping carts and product catalogs during flash sales.
- Mobile application backends with unpredictably fluctuating traffic.

---

## 2. Amazon RDS (Relational Database Service)

### 2.1 What is Amazon RDS?
**Amazon Relational Database Service (Amazon RDS)** makes it easy to set up, operate, and scale a relational database in the cloud. It automates time-consuming administrative tasks such as hardware provisioning, database setup, software patching, and continuous backups while keeping the database engine native and compatible.

### 2.2 Supported Database Engines
Amazon RDS supports six popular relational database engines:
1. **Amazon Aurora** (MySQL & PostgreSQL compatible, cloud-native high performance)
2. **PostgreSQL**
3. **MySQL**
4. **MariaDB**
5. **Oracle Database**
6. **Microsoft SQL Server**

### 2.3 DB Instances
- A **DB Instance** is an isolated database environment in the cloud.
- Composed of compute (CPU/RAM sizing based on DB instance classes, e.g., `db.t3.micro`, `db.r6g.large`) and persistent block storage (EBS gp3 or Provisioned IOPS io1).

### 2.4 RDS Security
- **Network Isolation**: Placed inside private subnets of an Amazon VPC; inaccessible from the public internet.
- **Access Control**: Governed by VPC Security Groups restricting inbound connections to application tier security groups on standard ports (e.g., 5432 for PostgreSQL, 3306 for MySQL).
- **Encryption at Rest**: AWS KMS encryption for database storage, automated backups, and read replicas.
- **Encryption in Transit**: Enforced SSL/TLS connections for all client-to-database queries.

### 2.5 Backups & Recovery
- **Automated Backups**: Continuous daily snapshots + transaction logs (WAL) allowing Point-in-Time Recovery (PITR) down to the second within a retention window (1 to 35 days).
- **Manual DB Snapshots**: User-initiated backups stored in Amazon S3 that persist indefinitely even if the DB instance is deleted.

### 2.6 Multi-AZ Deployments (High Availability)
- Creates a primary DB instance and synchronously replicates data to a **standby instance in a separate Availability Zone**.
- In the event of planned maintenance or hardware failure, RDS performs an **automatic failover** to the standby within 60–120 seconds with zero manual DNS reconfiguration.
- *Note:* Standby instances cannot serve read traffic.

### 2.7 Read Replicas (Scalability)
- Uses asynchronous replication to maintain up to 15 read-only copies of the primary DB instance.
- **Use Case**: Offloading read-heavy reporting queries and analytical workloads from the primary master database.
- Can be promoted to a standalone master database if needed.

### 2.8 RDS Common Use Cases
- Complex transactional enterprise systems (ERP, CRM) requiring ACID compliance and complex SQL multi-table joins.
- Legacy software migration from on-premises data centers to AWS.
- Financial accounting, banking transactions, and order fulfillment systems.

---

## 3. Comparison Matrix: DynamoDB vs. RDS

| Dimension | Amazon DynamoDB | Amazon RDS |
|---|---|---|
| **Data Model** | NoSQL (Key-Value / Document) | Relational (SQL Tables / Rows / Columns) |
| **Schema** | Flexible / Schema-less | Rigid / Structured Schema defined in advance |
| **Scaling** | Horizontal (Auto-partitioning, virtually infinite) | Vertical (Compute/RAM resize) + Read Replicas |
| **Server Management** | Completely Serverless (Pay per request or provisioned capacity) | Dedicated DB Instance provisioned (managed maintenance) |
| **High Availability** | Built-in Multi-AZ replication by default | Optional Multi-AZ synchronous standby toggle |
| **Transactions** | ACID transactions supported on single/multiple items | Native full relational ACID transactions across tables |
| **Query Flexibility** | Optimized for primary key lookups; secondary indexes (GSI/LSI) | Full SQL: joins, aggregates, group-by, window functions |
