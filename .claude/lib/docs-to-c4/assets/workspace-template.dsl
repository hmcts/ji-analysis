// docs-to-c4 starter template.
// Replace the placeholder names/tech with values derived from the distillate.
// Keep the `views` block and `styles` as-is — they give a decent default look.
// Delete any views you don't need (e.g., the Component view for containers
// where the docs don't support that level of detail).

workspace "Example System" "One-line description of the system, from the distillate." {

    model {

        // --- People (roles, not individuals) ---
        primaryUser = person "Primary User" "What this role does with the system."
        adminUser   = person "Admin"        "Operational role — configuration, support, oversight."

        // --- External software systems (third-party / other-team) ---
        sso = softwareSystem "Identity Provider" "Authenticates users." {
            tags "External"
        }

        // --- The system under study ---
        system = softwareSystem "Example System" "What the system does, in one sentence." {

            webApp = container "Web App" "Browser SPA used by primary users." "React / Vite"

            api = container "API" "REST backend for web and mobile clients." "Node.js / Express" {
                controllers = component "HTTP Controllers" "Translate HTTP into domain calls." "Express handlers"
                services    = component "Application Services" "Orchestration + domain logic." "TypeScript module"
                repository  = component "Persistence" "Reads/writes domain entities." "Prisma ORM"
            }

            db = container "Database" "Stores the system's persistent state." "PostgreSQL 15" {
                tags "Database"
            }
        }

        // --- Relationships ---
        primaryUser -> webApp "Uses" "HTTPS"
        adminUser   -> webApp "Administers via" "HTTPS"

        webApp -> api "Calls" "JSON/HTTPS"

        controllers -> services   "Delegates to"
        services    -> repository "Uses"
        repository  -> db         "Reads from and writes to" "JDBC"

        webApp -> sso "Authenticates users via" "OIDC"
        api    -> sso "Validates tokens with"  "JWKS"
    }

    views {

        systemContext system "SystemContext" {
            include *
            autoLayout lr
        }

        container system "Containers" {
            include *
            autoLayout tb
        }

        component api "ApiComponents" {
            include *
            autoLayout lr
        }

        styles {
            element "Person" {
                shape Person
                background #08427B
                color #ffffff
            }
            element "Software System" {
                background #1168BD
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #438DD5
                color #ffffff
            }
            element "Component" {
                background #85BBF0
                color #000000
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
}
