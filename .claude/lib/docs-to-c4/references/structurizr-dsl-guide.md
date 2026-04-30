# Structurizr DSL — crib sheet

Enough of the DSL to produce a workspace that `structurizr-site-generatr` renders nicely. The DSL reference lives at https://docs.structurizr.com/dsl — consult it if this sheet is missing something you need.

## Skeleton

```
workspace "<Name>" "<Short description>" {

    model {
        # People, systems, containers, components, relationships go here.
    }

    views {
        # systemContext / container / component / dynamic / deployment views.
        # Plus styles.
    }

}
```

A `.dsl` file always has exactly one `workspace { ... }` block. Everything else nests inside `model` or `views`.

## Identifiers vs names

```
customer = person "Customer" "A retail customer placing orders."
```

- `customer` — the identifier used to reference this element elsewhere in the DSL. camelCase, no spaces.
- `"Customer"` — the human-readable name shown in diagrams.
- `"A retail customer..."` — description. Keep to one sentence.

You reference the identifier for relationships:
```
customer -> webApp "Places orders via" "HTTPS"
```

## People, systems, containers, components

```
model {
    customer = person "Customer" "Places orders via the web."
    admin    = person "Admin"    "Manages the product catalogue."

    stripe   = softwareSystem "Stripe" "Payment processing." {
        tags "External"
    }

    shop = softwareSystem "Online Shop" "E-commerce platform." {
        webApp   = container "Web App"    "Browser-based SPA."       "React / Vite"
        mobile   = container "Mobile App" "iOS + Android app."        "React Native"
        api      = container "API"        "REST API for all clients." "Node.js / Express" {
            ordersController  = component "OrdersController"  "Handles /orders routes."    "Express handler"
            orderService      = component "OrderService"      "Order domain logic."        "TypeScript module"
            orderRepository   = component "OrderRepository"   "Persistence for orders."    "Prisma"
            stripeClient      = component "StripeClient"      "Wraps Stripe API calls."    "TypeScript module"
        }
        ordersDb = container "Orders DB"  "Stores orders and line items." "PostgreSQL 15" {
            tags "Database"
        }
        queue    = container "Event Bus"  "Order events."              "AWS SNS/SQS" {
            tags "Queue"
        }
    }
}
```

**Technology** is the 3rd argument on `container`/`component`. Always include it when the docs say so.

**Tags** are free-form labels used by the `styles` block. Common tags: `External`, `Database`, `Queue`, `Person`. You can invent more (e.g., `Legacy`, `Deprecated`).

## Relationships

```
customer -> webApp        "Submits orders via"           "HTTPS"
customer -> mobile        "Submits orders via"           "HTTPS"
admin    -> webApp        "Manages catalogue via"        "HTTPS"

webApp   -> api           "Calls"                         "JSON/HTTPS"
mobile   -> api           "Calls"                         "JSON/HTTPS"

ordersController -> orderService    "Delegates to"
orderService     -> orderRepository "Reads/writes"
orderService     -> stripeClient    "Uses"
orderRepository  -> ordersDb        "Reads/writes"         "JDBC"
stripeClient     -> stripe          "Creates payment intents via" "JSON/HTTPS"
orderService     -> queue           "Publishes `order.created` to" "AMQP"
```

Relationships can live inside the element block they originate from, or at the top level of `model`. Both work — pick whichever is clearer.

## Views

Inside `views { ... }`:

```
views {
    systemContext shop "SystemContext" {
        include *
        autoLayout lr
    }

    container shop "Containers" {
        include *
        autoLayout tb
    }

    component api "ApiComponents" {
        include *
        autoLayout lr
    }

    # Optional dynamic view for a key flow:
    dynamic shop "PlaceOrder" "A customer places an order" {
        customer -> webApp "Fills in checkout form"
        webApp   -> api    "POST /orders"
        api      -> ordersDb "INSERT order"
        api      -> stripe  "Create payment intent"
        api      -> queue   "Publish order.created"
        autoLayout lr
    }

    styles {
        element "Person" {
            shape Person
            background #08427B
            color #ffffff
        }
        element "External" {
            background #999999
            color #ffffff
        }
        element "Database" {
            shape Cylinder
        }
        element "Queue" {
            shape Pipe
        }
    }

    theme default
}
```

### View keys (the second argument)

The view key is a stable identifier used in URLs in the generated site. Use PascalCase, no spaces. Good: `"SystemContext"`, `"ApiComponents"`, `"DeploymentProd"`. Bad: `"context"`, `"view 1"`.

### autoLayout directions

- `lr` — left to right (good for linear request flows)
- `tb` — top to bottom (good for hierarchical Container views)
- `bt`, `rl` — rare

## Things that trip the parser

- **Strings must be quoted.** Unquoted element names with spaces will error.
- **Identifiers must be unique** across the whole workspace. Scoping inside containers does not give you a fresh namespace.
- **`tags` inside an element block takes a comma-separated list:** `tags "External,Legacy"` **or** `tags "External" "Legacy"` — both accepted; don't mix commas and whitespace inconsistently.
- **Every element referenced in a view must exist in the model** — `include *` at a given scope only includes elements visible from that scope.
- **Comments** start with `#` or `//`. Use freely.

## Minimal "context-only" workspace (fallback)

If the docs don't support containers at all, this still renders and is useful:

```
workspace "Acme" "Acme platform" {
    model {
        user = person "Customer"
        acme = softwareSystem "Acme Platform" "Our product."
        sso  = softwareSystem "Corporate SSO" "Third-party IdP." { tags "External" }

        user -> acme "Uses"
        acme -> sso  "Authenticates users via" "OIDC"
    }
    views {
        systemContext acme "SystemContext" { include *; autoLayout lr }
        styles {
            element "Person"   { shape Person; background #08427B; color #ffffff }
            element "External" { background #999999; color #ffffff }
        }
        theme default
    }
}
```
