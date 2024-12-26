## Overview
Pongfu is a web-based augmented reality (AR) Pong game powered by a microservices backend and a lightweight frontend. The backend combines pure Ruby microservices and pre-built Docker images, communicating to the frontend via the Pongfu API.

### Disclaimer
This is a 42 school project that is part of the common curriculum, **some design choices are forced by the project subject**. Also, only some of the brainstormed features are implemented because of time constraints. In the following documentation everything written in *italic* has to be interpreted as W.I.P.

# System Design
![system_design](https://github.com/user-attachments/assets/56062867-eec0-461c-bc22-acbbc88a7c87)

## Web Server (NGINX)

### Reasoning
NGINX is chosen for its high performance, scalability, ease of integration and lightweight footprint.

### Responsibilities
- **Reverse Proxy**: Routes incoming requests to the appropriate backend services, reducing backend exposure. By acting as reverse proxy, it is the only service exposed to the outside, minimizing the overall attack surface and enhancing system security.  
- **Websocket Handling**: Manages persistent connections for real-time data exchange, such as game state updates or player interactions.
- **SSL Termination**: Offloads the overhead of encrypting and decrypting HTTPS traffic from backend services, improving overall performance and security.
- **General Rate Limiter**: Protects the system from abuse or denial-of-service attacks by controlling the overall rate of incoming requests, rather than applying limits on a per-resource or per-user basis.  
- ***Entire API Calls Caching***: Temporarily stores responses for frequently accessed API endpoints, reducing the load on backend services and improving response times for users.
- ***Load Balancer***: Distributes incoming traffic across multiple instances of API Gateway services to ensure even workload distribution, high availability, and improved system reliability.
- ***Blacklisting***: Restricts access to specific API endpoints or resources based on IP addresses for enhanced security.

<i>

## Mail-Transfer-Agent (Postfix)

### Reasoning
Postfix is chosen for its reliability, efficiency, and robust security features, making it a strong choice for managing email traffic in a stateless and scalable manner.

### Responsibilities
- **Stateless Email Handling**: Manages sending and receiving emails via SMTP in a stateless fashion, ensuring simplicity and ease of scaling.
- **Single Point of Exposure**: Acts as the sole service exposed to the outside for email communication, minimizing the attack surface and protecting the rest of the system from email-related vulnerabilities.
- **Queue Management**: Efficiently handles email queues for outgoing messages, retrying delivery if the recipient's server is temporarily unavailable.
- **Spam and Abuse Prevention**: Integrates with tools like SPF, DKIM, and DMARC to authenticate email messages and prevent spam or phishing attacks.
- **Connection Rate Limiting**: Controls the rate of incoming and outgoing email connections to prevent abuse or overloading.
- **TLS Encryption**: Secures email communication by encrypting SMTP traffic with Transport Layer Security (TLS), protecting sensitive data during transmission.
- **Domain-based Routing**: Routes emails to the correct destinations based on domain-specific configurations, ensuring accurate delivery.
- **Email Logging and Monitoring**: Maintains detailed logs for all email activity, enabling easier debugging and tracking of email delivery issues.
</i>

## API Gateway

### Reasoning
The API Gateway is responsible for routing client requests to the appropriate microservices, handling authentication, rate limiting, and other security features. It acts as the central entry point for all client interactions, offering a unified interface to various backend services. It acts as a bridge between the external REST and the internal gRPC APIs.

### Responsibilities
- **Fine-Grained Rate Limiter**: Limits the rate of requests to different API endpoints based on predefined thresholds, preventing abuse and ensuring fair resource usage.
- **JWT Validation**: Verifies the validity of incoming JSON Web Tokens (JWTs) for authentication, bouncing off unaothorized requests as soon as possible.
- **Role Validation**: Ensures that the requesting user has the appropriate role/permissions to access specific API endpoints, preventing unauthorized access to sensitive data or services.

### Scalability
- Non-Blocking sockets
- Async I/O with fibers
- Early Bad Request detection

## User

### Reasoning
The User service handles the business logic of all the user-related requests, such as registration, login, friend requests.

## Match

### Reasoning
The Match service handles the business logic of all the match-related requests, such as starting and joining matches or retrieving matches info.

## Tournament

### Reasoning
The Tournament service handles the business logic of all the tournament-related requests, such as starting and joining tournament or retrieving tournament info.

## Auth

### Reasoning
The Auth Service is responsible for handling user authentication and authorization, providing secure token-based access to the system. It ensures that only authorized users can access the system by issuing JWTs, managing two-factor authentication (2FA) keys, generating Time-based One-Time Passwords (TOTP), verifying user emails, and securely hashing passwords.

### Responsibilities
- **JWT Issuer**: Generates JSON Web Tokens (JWTs) upon successful authentication. These tokens are used for secure, stateless authentication in subsequent API requests, ensuring users are authorized to access protected resources.
- **2FA Keys Issuer**: Issues unique keys for users enabling two-factor authentication (2FA). This key is used in combination with the user’s password to provide an extra layer of security during login attempts.
- **TOTP Generation**: Generates Time-based One-Time Passwords (TOTP) as part of the 2FA process. These passwords are generated using a shared secret and are valid for a short period, typically 30 seconds, ensuring dynamic, time-sensitive security.
- **JWT Blacklist Management**: Manages a blacklist of revoked JWTs to prevent unauthorized access to the system. When a user logs out or their token is compromised, the JWT is added to the blacklist, preventing further use.
- **Password Hashing**: Securely hashes user passwords before storing them in the database. The hashing is performed using industry-standard algorithms (e.g., bcrypt or Argon2) with a salt, ensuring that sensitive user data is not stored in plaintext and is resistant to brute-force attacks.
- ***Email Verification**: Sends verification emails to users upon registration. This process ensures the validity of user-provided email addresses and prevents fraudulent account creation. The user must click the verification link in the email to confirm their account.

<i>

## Email Broker

### Reasoning
The Email Broker acts as a middleware service responsible for managing email communication between users and the Mail-Transfer-Agent (MTA). It forwards outgoing emails to the MTA, keeps a record of email accounts, and handles retry logic for failed email deliveries. This service ensures reliable email transmission and management within the system.

### Responsibilities
- **Email Forwarding to MTA**: The Email Broker forwards outgoing emails to the Mail-Transfer-Agent (MTA) for actual delivery. It acts as an intermediary between the application services and the MTA, ensuring that email content and metadata are properly passed on for processing.
- **Record Keeping of Email Accounts**: Maintains a record of email accounts for users or services within the system. This includes storing relevant details like email addresses, associated users, and account status. The service ensures email addresses are valid and helps manage any email-specific configurations.
- **Retry Logic**: Implements retry mechanisms for email deliveries that fail due to temporary issues (e.g., the recipient's mail server being unavailable). The retry logic ensures that failed email deliveries are re-attempted at configurable intervals, reducing the chances of lost emails due to transient failures.
- **Handling Incoming Support Emails**: Processes incoming support emails by identifying the source, categorizing the issue, and routing the email to the appropriate team or service.
</i>

## Notification

<i>

### Reasoning
The Notification Service is responsible for delivering real-time notifications and alerts to users. This service ensures that players are promptly informed about important events such as match invitations, friend requests, and online status changes. By centralizing all notification functionalities, the system ensures consistent and timely communication across various user interactions.

### Responsibilities
- **Match Invitations**: Sends notifications to users when they receive an invitation to join a match. The service ensures that the invitation is delivered in a timely manner and may include relevant details like match start time, participants, and game settings.
- **Friend Requests**: Notifies users when they receive a friend request from another player. The notification includes details such as the sender’s username and the ability to accept or reject the request.
- **Online Status Notifications**: Sends real-time notifications to users when a friend or a player they follow comes online. This helps keep users informed about when their friends or teammates are available to play or interact.

### Scalability
- Server-Side-Events
</i>

## Game State

### Reasoning
The Game State Service is responsible for managing the real-time state of ongoing games. It ensures smooth communication between players and the game logic through WebSockets, allowing for continuous updates of game stats and player interactions. This service is essential for providing a seamless and interactive multiplayer gaming experience.

### Responsibilities
- **Manages WebSockets**: Establishes and maintains WebSocket connections between the game server and the players' clients. The service handles communication in real-time, allowing for instantaneous updates of game events, such as player actions, game status, or environmental changes.
- **Game State Updates**: Continuously updates the game state by tracking variables like player scores, ball position, game duration, and health. This includes sending real-time updates to connected players whenever the game state changes.
- **Synchronizes Players**: Ensures that all players in the game are synchronized, receiving the same updates at the same time, which is crucial for a smooth and fair gaming experience.
- **Game Event Handling**: Handles in-game events, such as player actions (e.g., hitting the ball, scoring points), and sends relevant updates to all connected clients via WebSockets.
- **Game Stats**: Collects and updates key statistics related to the game, including player performance and scores. These stats are transmitted to clients as part of the game state updates to ensure that players always have the latest information.

### Scalability
- Web-Sockets
- Connection Pooling
- Queue based events

## Matchmaking

### Reasoning
The Matchmaking Service is responsible for pairing players together in a competitive or cooperative environment. It ensures players are matched based on predefined criteria such as skill level, latency, or other parameters that contribute to a fair and enjoyable game experience.

### Responsibilities
- **Matchmaking Pool**: Maintains a pool of waiting players who are seeking to be matched. The service continually monitors this pool and dynamically forms matches based on players' attributes (e.g., skill level, preferences). It ensures efficient resource usage and that players are paired quickly for a smooth gaming experience.
- ***Fallback Logic**: In cases where a perfect match cannot be found (e.g., no other players with similar skill levels), the service implements fallback logic. This allows the system to make trade-offs, such as relaxing skill requirements or allowing the match to proceed with slight imbalances. This ensures that players are not kept waiting too long and maintains a smooth user experience.*
- **Finds Available Players**: Continuously searches for available players within the matchmaking pool. The service evaluates players' preferences (e.g., mode, team size) and availability to create matches. It ensures that no players are left unmatched for extended periods.

### Scalability
- Caching Player Data
- Asynchronous Processing

<i>

## AI

### Reasoning
The AI Service is responsible for simulating client actions to provide a dynamic and challenging opponent for players. It offers different difficulty levels to cater to a wide range of player skills, ensuring that the game remains enjoyable and challenging regardless of the player's experience. By simulating intelligent actions, the AI contributes to a more engaging and competitive game environment.

### Responsibilities
- **Simulates Client Actions**: The AI simulates the actions of a player, including movements, responses to ball trajectories, and decision-making processes (e.g., when to hit the ball, when to move). It behaves like a human player, creating realistic interactions with the game environment.
- **Different Difficulty Levels**: The AI provides varying difficulty levels, adjusting its response time, accuracy, and strategy. On lower difficulty levels, the AI may make more mistakes or move slower, while on higher levels, the AI becomes more reactive, faster, and strategic, offering a tougher challenge for players.
- **Dynamic Difficulty Adjustment**: The AI can adjust difficulty levels dynamically based on the player's performance. If a player consistently wins, the difficulty level can be increased, whereas if the player struggles, the difficulty can be reduced to maintain engagement.

## Scalability
- **Connection Pooling**

</i>

## Blockchain Service

### Reasoning
The Blockchain Service is responsible for interacting with the Ethereum blockchain via the node service. It enables the application to execute smart contract functions, retrieve data from the blockchain, and send transactions to be mined. This service is crucial for enabling blockchain-based features, such as handling transactions or smart contract-based game logic.

### Responsibilities
- **Interacts with the Smart Contract(s)**: The Blockchain Service interacts with deployed smart contracts on the Ethereum blockchain. It can call functions of the smart contract, retrieve data, and trigger specific contract actions based on the application’s needs.
- **Transaction Management**: Handles sending transactions to the blockchain and manages the confirmation process. It ensures that transactions are properly broadcast to the network and monitors their status until they are successfully mined.

### Scalability
- Node Pooling

</i>

## Database (PostgreSQL)

### Database ERD
![Restored DB](https://github.com/user-attachments/assets/c3245e1f-912a-433b-b18a-9f4fb3f95b47)

### Reasoning
PostgreSQL is chosen as the primary relational database for its robust support for ACID transactions, scalability, and advanced features like support for complex queries and indexing. It is used as a central repository for all system data, ensuring consistency, reliability, and high performance.

### Responsibilities
- **Global Database**: Serves as the central storage for all application data, including user profiles, game data, and more. It ensures data consistency and availability across all services in the system.
- **Role-Based Access Control (RBAC)**: Ensures secure access to the database by enforcing permissions based on user roles. This prevents unauthorized access to sensitive data and restricts actions based on user responsibilities within the system.
  
- **Connection Pooling**: Manages database connections efficiently by reusing connections from a pool, reducing the overhead of repeatedly opening and closing connections. This improves the performance of database queries and ensures optimal resource usage under heavy load.

### Scalability
- Materialized Views
- Connection Pooling
- Prepared Statements
- Indexing
- Partitioning
- *Fragmentation*
- *Read Replicas*

<i>

## Cache (Memcached)

### Reasoning
Memcached is chosen for its minimal in-memory key-value store capabilities, high performance, and scalability. It is used to cache frequently accessed data, reducing the load on the database and improving response times for read-heavy operations. Memcached is ideal for storing transient data that can be quickly retrieved without the need for complex queries.

### Responsibilities
- **Caches Common Database Queries**: Stores the results of frequently executed database queries, reducing the need for repeated querying of the database. This helps to speed up response times and reduce database load.
- **Cache for All Services**: Acts as a shared caching layer for all services in the system. By providing a centralized cache, Memcached ensures that data used by different services is readily available, improving system-wide performance.

### Scalability  
- *Replication*
- *Sharding*

</i>
<i>

## Node (Geth)

### Reasoning
Geth (Go Ethereum) is chosen for its ability to self-host an Ethereum node, providing full control over the interaction with the Ethereum blockchain. This service ensures the system stays in sync with the blockchain state and is capable of posting transactions directly to the mempool.

### Responsibilities
- **Self-Hosted Ethereum Node**: Hosts a local instance of an Ethereum node, allowing the system to interact directly with the Ethereum blockchain. This provides full control over blockchain interactions without relying on third-party services.
- **Keeps Synced Blockchain State**: Continuously synchronizes with the Ethereum network to keep the local blockchain state up to date. This ensures that all transactions, smart contract events, and balances are accurate and current.
- **Posts Transactions to the Mempool**: Sends new transactions to the Ethereum mempool for validation and inclusion in blocks. This enables the system to interact with smart contracts and perform actions on the blockchain.

### Scalability
- Sync Optimization
- Disk Storage

</i>

## Logstash

### Reasoning
Logstash is chosen for its powerful capabilities in collecting, filtering, enriching, and labeling logs. It acts as a central log management service, providing the necessary tools to process logs from multiple sources and forward them to the appropriate storage or analysis services.

### Responsibilities
- **Collects Logs**: Gathers logs from various sources across the system, including application logs, system logs, and other services, ensuring that all relevant information is collected for analysis and monitoring.
- **Filtering**: Filters incoming log data to exclude irrelevant or noisy information. This helps to focus on meaningful logs and reduces the volume of data sent to storage or analysis platforms.
- **Enrichment**: Enhances log data by adding context, such as metadata or information from external sources, making the logs more useful for troubleshooting, analysis, and insights.
- **Labeling**: Adds labels or tags to logs to categorize them based on type, severity, or source. This makes it easier to identify patterns, troubleshoot issues, and segment logs for analysis.

### Scalability  
- *Clustered Setup*
- *Pipeline Optimization*


## Elasticsearch

### Reasoning
Elasticsearch is chosen for its powerful full-text search capabilities, scalability, and ability to handle large volumes of log data efficiently. As a distributed search and analytics engine, it is ideal for storing and querying logs, enabling fast retrieval of insights and detailed analysis.

### Responsibilities
- **Logs Database**: Stores and indexes log data collected from various sources. Elasticsearch is optimized for high-speed data retrieval and can efficiently manage and search through massive volumes of logs, making it an essential component for centralized logging and monitoring.
- **Full-text Search**: Provides powerful search capabilities that allow for complex queries across structured and unstructured log data. This enables users to find specific logs based on content, timestamp, severity, and other parameters.
- **Log Aggregation**: Aggregates log data from multiple sources, enabling easy access and analysis of logs from various services, applications, and systems in a unified manner.

### Scalability  
- Elastic Scaling
- *Sharding*
- *Replication*
  

## Kibana

### Reasoning
Kibana is chosen for its seamless integration with Elasticsearch, providing a powerful interface for visualizing and analyzing log data. Its intuitive dashboard UI allows users to interact with large datasets, turning raw log information into actionable insights. Kibana is essential for transforming complex log data into visual representations, making monitoring and troubleshooting more accessible.

### Responsibilities
- **Logs Visualization**: Kibana allows users to visualize log data through various types of charts, graphs, and maps. This helps in understanding trends, identifying anomalies, and gaining insights from large volumes of log data.
- **Logs Monitoring**: Provides real-time monitoring of log data, enabling users to set up alerts for specific conditions or thresholds. This feature ensures that users can quickly respond to critical events, such as system errors or security breaches.
- **Dashboard UI**: Kibana’s dashboard allows users to create customized views of their log data. The UI provides drag-and-drop functionality to arrange widgets, offering a tailored experience for each user’s needs, whether they are tracking system health, application performance, or user activity.

<i>

## Prometheus

### Reasoning
Prometheus is chosen for its robust time-series database and built-in support for collecting and querying performance metrics. It is widely used for monitoring and alerting purposes due to its ability to gather real-time data across distributed systems. Prometheus integrates seamlessly with Grafana for visualizing performance trends and anomaly detection, making it an essential component of the monitoring infrastructure.

### Responsibilities
- **Collects Performance Metrics**: Prometheus continuously collects metrics from various services and applications, such as CPU usage, memory consumption, request rates, and error rates. This data is stored in a time-series format, enabling detailed performance analysis over time.
- **Detects Anomalies**: Prometheus provides a powerful querying language (PromQL) that can be used to detect anomalies in performance data. Alerts can be configured based on specific conditions, such as sudden spikes in resource usage, allowing teams to quickly identify issues before they impact users.

</i>

<i>

## Grafana

### Reasoning
Grafana is chosen for its flexibility and power in visualizing time-series data, particularly for monitoring performance metrics collected by Prometheus. It provides rich, customizable dashboards that allow for real-time monitoring of system health, with the ability to set up alerts for specific thresholds or anomalies. Grafana's open-source nature and strong community support make it a go-to tool for visualizing complex data across multiple services.

### Responsibilities
- **Visualize Historic Performance**: Grafana allows users to create dashboards that display historical performance metrics, enabling teams to analyze trends over time. This is essential for identifying patterns, diagnosing issues, and understanding system behavior under various loads or conditions.
- **Monitoring Dashboard**: Grafana provides an intuitive, interactive dashboard UI where users can monitor the health of the entire system. Metrics such as response times, resource utilization, and error rates can be displayed in real-time, offering a centralized view of performance.
- **Alerting System**: Grafana integrates with Prometheus to provide alerting functionality. Users can define alert rules for specific metrics or conditions, such as high latency or server downtime. Alerts are sent via channels like email, Slack, or other integrations, allowing for immediate response to critical issues.

</i>

# Developer Guidelines

## Table of Contents
- [General Guidelines](#1-general-guidelines) 
- [Directory Structure](#2-directory-structure) 
- [Naming Conventions](#3-naming-conventions) 
- [Docker](#4-docker) 

## 1. General Guidelines
- **Consistency**: Follow the same structure, naming conventions, and coding practices across all services.
- **Documentation**: Each service should be documented in this README.md file
- **Error Handling**: Services should only shut down after fatal system related errors and immediately notify prometheus.

## 2. Directory Structure
```
/
│
├── srcs/
  ├── services/
    ├──api_gateway/
      ├──build/
      ├──Dockerfile
      └──README.md
    ├──auth/
    └──...
  └── docker-compose.yml
│
├── .env
├── Makefile
└── README.md
```

## 3. Naming Conventions

### 3.0 General Conventions
- Avoid redundancy in naming by not repeating the entity type.
  - Example: Do **not** include `service` in service names (e.g., `auth` instead of `auth-service`).
  - Example: Do **not** include `user` in usernames (e.g., `admin` instead of `admin-user`).
  - Example: Do **not** include `volume` in volume names (e.g., `db_data` instead of `db-volume`).
  - Example: Do **not** include `net` in network names (e.g., `backend` instead of `backend-net`).
- Names should be short but descriptive, prioritizing clarity over brevity.

### 3.1 File and Folder names
- Use **snake_case** for folder and file names.
- **Class** files should have the same name as the Class
- Use `.template` suffix on files that need environvment variables substitution

## 3.2 Variables, Functions and Classes
- Follow the most official naimng conventions of the programming language
  - Example: [Ruby style](https://rubystyle.guide/)
  - Example: [gRPC syle](https://protobuf.dev/programming-guides/style/)
  - Example: *RESTFUL* standard for rest APIs

### 3.4 Docker-Related Naming Conventions
- Refer to the [Docker Guidelines](#docker-guidelines) for additional details.
- Use **descriptive, short names** for:
  - Containers: Use the service name directly (e.g., `api_gateway`).
  - Volumes: Name them after their purpose (e.g., `db_data` for database storage).
  - Networks: Use context-specific names (e.g., `frontend`, `backend`).
  - Images: Follow the format `<project>-<service>` (e.g., `pongmasters-auth`).

### 3.5 Database Naming Conventions
- Use **CamelCase** plural names for Tables.
  - Table example: `Matches`.
- Use **snake_case** for column names.
  - Column example: `last_login_at`.
- Prioritize changing names over enclosing it in quotes when not available.
  - Example: `password` in postgres is restricted and becomes `psw` instead of `'password'`

### 3.6 Logging and Metrics
- Use a consistent `<service_name>` tag for logs across all services.
  - Example: `[api_gateway] INFO Request received`.
- Name metrics descriptively and consistently:
  - Example: `http_request_duration_seconds`, `user_login_attempts_total`.
- Ensure that returned responses don't hint at the internal infrastructure.
  - Example: `Database connection error` instead of `user_id must be an integer`.
- Propagate the original request ID across every internal service call for traceability.


## 4. Docker

### 4.1 General Docker Practices
- Don't pull precompiled images from DockerHub
- Build images from the latest stable version of **alpine**
- Avoid running containers as `root` user
- Keep containers stateless, use external storage for persistent data
- Use **docker secrets** for sensitive credentials
- Only run **initialization scripts** in the entrypoints
- Never use `*` **wildcards**
- Prioritize minimalism

### 4.2 Docker Compose
- Template:
  ```yaml
  services:

    service_name:
      build:
        context: ./services/service_name
        dockerfile: Dockerfile
        args:
      container_name: service_name
      environment:
      volumes:
      secrets:
        - source:
          target:
          uid:
          mode: 0400
      ports:
      networks:
      restart: always
      depends_on:
      init: true

    service_name:
  
  volumes:
  
  secrets:

  networks:

  ```
- Only build from Dockerfiles
- Only pass the strictly necessary **environvment variables**
- Never include the whole .env file
- Environvment variables that are only needed during **build time** should be passed as `args`
- Always specify **volumes** permissions

### Dockerfile
- Template:
  ```Dockerfile
  FROM alpine:3.19

  SHELL ["/bin/ash", "-c"]

  RUN apk add --no-cache

  RUN mkdir -p

  COPY ./build/

  RUN adduser -DHS service_name
  RUN chown -R service_name:service_name 
  RUN chmod -R +x /usr/local/bin/

  WORKDIR
  EXPOSE 

  ENTRYPOINT []
  HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD []
  ```
  - Always specify the `SHELL`
  - Keep the **order** of instructions as in the example
  - Never use `--chmod` or `--chown` directly on `ADD` or `COPY` commands
  - Always specify a `WORKDIR`
  - Always specify a `HEALTHCHECK`
  - Document open ports with `EXPOSE`
  - Use full paths even if `WORKDIR` is set
  - Keep consistency between all Dockerfiles
