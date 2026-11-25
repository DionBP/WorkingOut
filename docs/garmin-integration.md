# Garmin integration feasibility

WorkingOut uses Garmin Connect → Apple Health for current imports. This requires an iPhone, a paired Garmin device, and sharing enabled for the workout data types. Garmin Connect must be open during the sync that transfers data to Apple Health. Available history and fields vary, and Garmin does not transfer GPS tracks through this path. [Garmin support](https://support.garmin.com/da-DK/?faq=lK5FPB9iPF5PXFkIpFlFPA)

## Direct access options

| Option | Prerequisites and authentication | Data and limits |
| --- | --- | --- |
| Garmin Personal | A Garmin Connect account with access to the Personal program. Use its developer portal to obtain an API key and generate access tokens for the developer's own account. | Pull access to personal activity JSON and FIT plus health JSON. Suitable for Dion's development evaluation. |
| Garmin Activity API | Apply for Garmin's Business program and register an app. Verify production authorization, token handling, capabilities and contractual terms in the approved portal. | Activity JSON and FIT for activity ingestion. Starter has push delivery, limited users and no historical retrieval. Enterprise lists push or ping/pull and historical access subject to terms. |
| Garmin Health API | Business program approval and consent for each relevant scope. Confirm supported metrics, authentication and commercial terms with Garmin. | Health summaries in JSON. Use only if a later feature needs wellness data or the specific metrics validated in the portal. |
| Connect IQ | Supported device, current Connect IQ SDK, Monkey C app or data field, and Garmin store review for distribution. Authenticate separately if connecting to a web service. | On-device sensor and FIT capabilities depend on model, app type and permissions. Useful for a Garmin training interface or recording supplement. |

Garmin publishes different terms for Starter and Enterprise, with tailored Enterprise commercial terms. Confirm current fees, user capacity, attribution conditions, supported geographies, and rate limits before committing to a paid integration. Credentials, production access, and Garmin hardware validation are pending. [Garmin Developer Program](https://developer.garmin.com/gc-developer-program/overview/) [Connect IQ SDK](https://developer.garmin.com/connect-iq/overview/)

## Proposed implementation

Start with an opt-in Personal evaluation against Dion's own records and a small local fixture set. Check Garmin's actual Activity schemas for distance, route, laps, timestamps, heart rate, strength details and source IDs. Verify sync delay, corrections and deletes, duplicate delivery, and data available from Dion's watch.

For a multi-user integration, isolate Garmin authorization and ingestion in an approved backend adapter. Store provider secrets server-side, encrypt tokens, request minimum scopes and support revocation, account disconnect, and deletion. Map each activity to a normalized record keyed by provider and external ID, ingest retries idempotently, preserve source provenance, and expose uncertain Apple Health matches for user reconciliation. Document retention and explicit consent before sending any data off the device. Keep the existing Apple Health import available throughout.
