# C4 model — what belongs in each view

Quick primer for the docs-to-c4 skill. Read this before synthesising a workspace.

## The four levels

| Level | Audience | Question it answers | Things inside |
|-------|----------|---------------------|---------------|
| 1. System Context | Everyone (non-technical OK) | How does this system fit into the world? | The system + people + other systems it integrates with |
| 2. Container | Technical stakeholders | What are the high-level building blocks inside the system? | Apps, APIs, DBs, queues, workers, browser/mobile SPAs, serverless fns |
| 3. Component | Engineers working on a container | How is one container structured internally? | Services, controllers, repositories, domain modules — named groupings of code |
| 4. Code | Engineers working on a component | How is a component implemented? | Classes, structs, packages — usually omitted in Structurizr, left to the IDE |

The docs-to-c4 skill always produces **Level 1**, and **Level 2** and **Level 3** whenever the distillate supports them. Level 4 is out of scope.

## What counts as…

### Person

A **role**, not an individual. Examples: `Customer`, `Warehouse Operator`, `Compliance Officer`, `System Admin`. A non-human external system is not a person — it's a software system.

### Software System

A logical system from the user's point of view. Has a single owning team in most cases. A "system" can internally contain many deployable things — those are containers, not systems. Rule of thumb: if two things are deployed together and evolve together, they're containers inside one system; if they're released independently by different teams with different SLAs, they're different systems.

### External Software System

A software system the one you're modelling talks to but does **not** own. Examples: `Stripe`, `SendGrid`, `Corporate SSO`, `Legacy CRM (2002)`. Style these with `tag "External"` so the site renders them differently.

### Container

A runtime process / deployable thing. Typical examples and their technology labels:

| Container | Technology examples |
|-----------|---------------------|
| Web application (browser) | `Single-Page App`, `React / Vite`, `Next.js 14 (SSR)` |
| Mobile app | `iOS (Swift)`, `Android (Kotlin)`, `React Native` |
| API / Backend service | `Node.js / Express`, `Go net/http`, `Django / Gunicorn` |
| Background worker | `Python / Celery`, `Go worker`, `Node.js / BullMQ` |
| Relational database | `PostgreSQL 15`, `MySQL 8`, `Amazon RDS Aurora` |
| NoSQL / cache | `DynamoDB`, `MongoDB Atlas`, `Redis 7` |
| Message broker | `Apache Kafka`, `RabbitMQ`, `AWS SNS/SQS` |
| Object storage | `Amazon S3`, `Azure Blob Storage` |
| Serverless / function | `AWS Lambda`, `Cloudflare Worker` |

A container is not a container image. The C4 word predates Docker.

### Component

A named, logical grouping of code inside a container. Examples inside an `Orders API` container: `OrderController`, `OrderService`, `OrderRepository`, `PaymentClient`. Only model components when the docs describe them — don't invent.

## Relationships

Every relationship needs:

- A **verb phrase** describing direction and intent: `"Places orders via"`, `"Reads customer profiles from"`, `"Publishes `order.created` events to"`, `"Authenticates users via"`.
- A **technology/protocol** where the docs say so: `"JSON/HTTPS"`, `"gRPC"`, `"JDBC"`, `"AMQP"`.

Good:
```
user -> webApp "Submits orders via" "HTTPS"
webApp -> ordersApi "Calls" "JSON/HTTPS"
ordersApi -> ordersDb "Reads from and writes to" "JDBC"
ordersApi -> stripe "Creates payment intents via" "JSON/HTTPS"
```

Bad:
```
user -> webApp "uses"
ordersApi -> ordersDb "connects"
```
Too vague to be useful.

## How to decide whether the docs support a Container / Component view

**Container view — require at least all of:**

- ≥ 2 clearly distinct runtime processes or data stores named in the docs.
- An indication of how they talk to each other (even informally — "the web app calls the API").

**Component view — require all of:**

- A container's internals described in prose (services, modules, packages, controllers named).
- At least 3 components worth naming inside that container.
- An indication of how they relate (calls, reads from, publishes to).

When in doubt, omit. An empty view is worse than no view.

## Handling ambiguity

- **Named but unexplained systems** (e.g., "we integrate with Jira"): include as an external system with a minimal description like `"External system (details not in source docs)"`.
- **Hinted-at databases** ("data is persisted"): include a `database` container with technology `"Unknown (not specified in source docs)"` and record the gap.
- **Multiple competing names for the same thing**: pick the clearest name and record the aliases in the description — don't create duplicate elements.

## Gaps block

If the docs have obvious holes, put a comment block at the top of `workspace.dsl`:

```
# GAPS (from source docs — to be clarified with the team)
# - No mention of authentication provider — modelled as generic `IdP`.
# - Persistence layer is not specified — `ordersDb` technology is unknown.
# - Deployment topology is not documented.
```

Mirror this list in the output `README.md` (i.e., `<input_folder>/output/README.md`) so it's visible to readers who won't open the DSL.
