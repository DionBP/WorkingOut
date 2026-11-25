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

## Phase 3 wearable planning

Start by testing Garmin's native strength workout on Dion's exact watch model and firmware. Use Garmin Connect to make a small scheduled strength workout with ordered exercises, repetition targets, weights and rest steps, then sync, complete it, and inspect the results. Native workouts are the simplest path if the device meets the guidance requirements. The public Training API description confirms publishing workouts and training plans to the Garmin Connect calendar after consent. Treat strength exercise mappings, weighted targets, repetition ranges, rest steps, native UI capabilities and completed result fields as approval and device validation items. Publication and retrieval are separate capabilities. Use Activity API/FIT to investigate completed results after access is granted. [Garmin Training API](https://developer.garmin.com/gc-developer-program/enterprise/training-api/) [Garmin developer portal](https://developerportal.garmin.com/developer-programs/connect-developer-api)

1. Apply for Garmin's Business developer program and request Training API access for WorkingOut. State the strength scheduling use case, exact watch models, intended user count, and data retention. Request Activity API access if structured completed results are needed.
2. After approval, register a sandbox app, confirm the authorization flow, scopes, supported countries, rate limits and commercial terms in the portal. Keep confidential credentials server-side if the approved integration requires them. Verify hosting and costs before committing.
3. Map approved Garmin exercise codes to stable WorkingOut IDs. Convert the existing `StructuredWorkoutDraft` into approved payloads. Its rows preserve warm-ups, order, kilograms, repetition ranges, rest, load type and the scheduled date. Resolve unmapped IDs explicitly and verify completed workout matching using provider identifiers.
4. If native guidance lacks required previous-set or recommendation controls, prototype a Connect IQ Device App for Dion's exact model. Use Monkey C and the official iOS Mobile SDK for compact signed-in device messages, download workout data while connected, persist local state, and replay result UUIDs on reconnect. Test device memory, supported SDK versions and Bluetooth behavior, then submit through Garmin's store review process. [Connect IQ Mobile SDK](https://developer.garmin.com/connect-iq/articles/core-topics/Mobile_SDK_for_iOS.html) [Connect IQ device support](https://developer.garmin.com/connect-iq/compatible-devices/)

Phase 3 implements the shared wearable model, an internal provider draft and mapping, and Apple Watch transport. Direct Garmin communication and approved payload formats remain unverified. Garmin Connect → Apple Health remains the shipping import path. No paid service or Garmin SDK dependency was added.
