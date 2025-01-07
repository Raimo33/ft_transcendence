## Overview
Pongfu is a web-based augmented reality (AR) Pong match powered by a microservices backend and a lightweight frontend. The backend combines pure Ruby microservices and pre-built Docker images, communicating to the frontend via the Pongfu API.

### Disclaimer
This is a 42 school project that is part of the common curriculum, **some design choices are forced by the project subject**. Also, only some of the brainstormed features are implemented because of time constraints. In the following documentation everything written in *italic* has to be interpreted as W.I.P.

# System Design
![Backend_design](https://github.com/user-attachments/assets/d4817c4a-008b-484d-84c4-697b0ab2b024)

## Web Server (NGINX)

### Reasoning
NGINX is chosen for its high performance, scalability, ease of integration, and lightweight footprint.

### Responsibilities
- **Reverse Proxy**: Routes incoming requests to the appropriate backend services, reducing backend exposure. By acting as a reverse proxy, it is the only service exposed to the outside, minimizing the overall attack surface and enhancing system security.
- **WebSocket Handling**: Manages persistent connections for real-time data exchange, such as match state updates or player interactions.
- **SSL Termination**: Offloads the overhead of encrypting and decrypting HTTPS traffic from backend services, improving overall performance and security.
- **General Rate Limiter**: Protects the system from abuse or denial-of-service attacks by controlling the overall rate of incoming requests, rather than applying limits on a per-resource or per-user basis.
- **API Calls Caching**: Temporarily stores responses for frequently accessed API endpoints, reducing the load on backend services and improving response times for users.
- **Load Balancer**: Distributes incoming traffic across multiple instances of API Gateway services to ensure even workload distribution, high availability, and improved system reliability.
- **Blacklisting**: Restricts access to specific API endpoints or resources based on IP addresses for enhanced security.

---

<i>

## Mail Transfer Agent (Postfix)

### Reasoning
Postfix is chosen for its reliability, efficiency, and robust security features, making it a strong choice for managing email traffic in a stateless and scalable manner.

### Responsibilities
- **Stateless Email Handling**: Manages sending and receiving emails via SMTP in a stateless fashion, ensuring simplicity and ease of scaling.
- **Single Point of Exposure**: Acts as the sole service exposed to the outside for email communication, minimizing the attack surface and protecting the rest of the system from email-related vulnerabilities.
- **Queue Management**: Efficiently handles email queues for outgoing messages, retrying delivery if the recipient's server is temporarily unavailable.
- **Spam and Abuse Prevention**: Integrates with tools like SPF, DKIM, and DMARC to authenticate email messages and prevent spam or phishing attacks.
- **Connection Rate Limiting**: Controls the rate of incoming and outgoing email connections to prevent abuse or overloading.
- **TLS Encryption**: Secures email communication by encrypting SMTP traffic with Transport Layer Security (TLS), protecting sensitive data during transmission.
- **Domain-Based Routing**: Routes emails to the correct destinations based on domain-specific configurations, ensuring accurate delivery.
- **Email Logging and Monitoring**: Maintains detailed logs for all email activity, enabling easier debugging and tracking of email delivery issues.

</i>

---

## App

### User
#### Reasoning
The User module manages all user-related functionalities, ensuring data integrity and security. It handles user registration, authentication, profile management, and ensures that user data adheres to defined validation rules.

#### Responsibilities
- **Email Validation**: Ensures that user emails are valid and properly formatted.
- **Password Management**: Validates password strength and securely hashes passwords before storage.
- **Display Name Validation**: Ensures that user display names meet the required format and constraints.
- **Avatar Handling**: Validates, compresses, and decompresses user avatars to optimize storage and display.
- **QR Code Generation**: Creates QR codes for user-related functionalities, such as two-factor authentication.
- **Session Management**: Manages user sessions, including generating and validating JWTs for authentication.
- **Cache Management**: Handles caching of user data to improve performance and reduce database load.

### Auth
#### Reasoning
The Auth module handles user authentication and authorization, providing secure token-based access to the system. It ensures that only authorized users can access the system by issuing JWTs, managing two-factor authentication (2FA) keys, generating Time-based One-Time Passwords (TOTP), verifying user emails, and securely hashing passwords.

#### Responsibilities
- **JWT Issuer**: Generates JSON Web Tokens (JWTs) upon successful authentication for secure, stateless authentication in API requests.
- **2FA Keys Issuer**: Issues unique keys for users enabling two-factor authentication (2FA), adding an extra security layer during logins.
- **TOTP Generation**: Creates Time-based One-Time Passwords (TOTP) as part of the 2FA process for time-sensitive security.
- **JWT Blacklist Management**: Manages a blacklist of revoked JWTs to prevent unauthorized access.
- **Password Hashing**: Securely hashes user passwords using algorithms like bcrypt or Argon2 with a salt.
- **Email Verification**: Sends verification emails to users upon registration to ensure valid email addresses.

### Match
#### Reasoning
The Match module manages match matches between users, including creating, updating, and deleting matches. It ensures that matches are properly recorded and that player statuses are accurately tracked.

#### Responsibilities
- **Match Retrieval**: Fetches user matches from the database with support for pagination and filtering.
- **Player Status Check**: Determines if a user is currently engaged in an active match.
- **Friendship Verification**: Checks if users are friends to allow match invitations.
- **Match Information Retrieval**: Provides detailed information about specific matches.
- **Match Lifecycle Management**: Handles the creation, updating, and deletion of matches, including setting winners and updating match statuses.

TODO add tournament module documentation
### Tournament
#### Reasoning
#### Responsibilities

### Matchmaking
#### Reasoning
The Matchmaking module pairs players together in a competitive or cooperative environment, ensuring fair and enjoyable matches based on predefined criteria such as skill level and latency.

#### Responsibilities
- **Matchmaking Pool**: Maintains a pool of waiting players and dynamically forms matches based on players' attributes.
- **Fallback Logic**: Implements fallback logic to relax match criteria if a perfect match is unavailable, ensuring players are not kept waiting too long.
- **Finds Available Players**: Searches for available players within the matchmaking pool, evaluating preferences and availability to create matches efficiently.
- **Match Invitations**: Manages sending and receiving match invitations between users, ensuring invitations are unique and valid.

---

<i>

### AI
#### Reasoning
The AI Service simulates client actions to provide dynamic and challenging opponents for players. It offers different difficulty levels to cater to various player skills, ensuring the match remains engaging.

#### Responsibilities
- **Simulates Client Actions**: Simulates player actions like movements and responses to match events to create realistic interactions.
- **Different Difficulty Levels**: Provides varying difficulty levels, adjusting its response time, accuracy, and strategy.
- **Dynamic Difficulty Adjustment**: Adjusts difficulty levels dynamically based on the player's performance to maintain engagement.

</i>

---

## Notification

### Reasoning
The Notification Service delivers real-time notifications and alerts to users, ensuring timely communication about important events such as match invitations, friend requests, and online status changes.

### Responsibilities
#TODO add more responsibilities

---

## Match State

### Reasoning
The Match State Service manages the real-time state of ongoing matchs, ensuring smooth communication between players and match logic through WebSockets for continuous updates.

### Responsibilities
- **Manages WebSockets**: Maintains WebSocket connections for real-time match updates.
- **Match State Updates**: Tracks and updates match variables like player scores, ball position, and match duration.
- **Synchronizes Players**: Ensures all players receive updates simultaneously for a fair gaming experience.
- **Match Event Handling**: Processes in-match events and sends relevant updates to clients.

---

## Database (PostgreSQL)

### Database ERD
![Restored DB](https://github.com/user-attachments/assets/c3245e1f-912a-433b-b18a-9f4fb3f95b47)

### Reasoning
PostgreSQL is chosen for its robust support for ACID transactions, scalability, and advanced features like complex queries and indexing. It ensures consistency, reliability, and high performance as the central repository for system data.

### Responsibilities
- **Global Database**: Stores all application data, ensuring consistency and availability across services.
- **Role-Based Access Control (RBAC)**: Enforces secure database access based on user roles.
- **Connection Pooling**: Reuses connections from a pool to reduce overhead and optimize resource usage.

---

## Cache (Memcached)

### Reasoning
Memcached is chosen for its high-performance in-memory key-value store capabilities. It reduces the load on the database and improves response times by caching frequently accessed data.

### Responsibilities
- **Caches Common Database Queries**: Stores results of frequently executed queries to reduce database load.
- **Cache for All Services**: Provides a centralized caching layer to improve performance across the system.

---

<i>

## Node (Geth)

### Reasoning
Geth (Go Ethereum) is chosen for its ability to self-host an Ethereum node, ensuring full control over blockchain interactions and the ability to post transactions directly to the mempool.

### Responsibilities
- **Self-Hosted Ethereum Node**: Hosts a local Ethereum node for direct blockchain interaction.
- **Keeps Synced Blockchain State**: Synchronizes with the Ethereum network to maintain an up-to-date blockchain state.

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
  ```
  - Always specify the `SHELL`
  - Keep the **order** of instructions as in the example
  - Never use `--chmod` or `--chown` directly on `ADD` or `COPY` commands
  - Always specify a `WORKDIR`
  - Document open ports with `EXPOSE`
  - Use full paths even if `WORKDIR` is set
  - Keep consistency between all Dockerfiles
