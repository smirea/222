# 222

A personal iOS and macOS client for [222](https://222.place). It shows the same data as the official app but with fewer steps: invites, available events, full event details, past events, people you've met, and the questionnaire answers that drive matching.

```sh
./scripts/run               # build, launch, and relaunch on save
./scripts/run -t mac        # native Mac app
./scripts/run -t "Stefan’s iPhone 15 Pro" --no-watch
```

Sign in by pasting your 222 token. `222 invites -s` in `~/code/scripts` refreshes it from Chrome, and `get_authed_member` returns it as `auth_token`.

## What differs from the official app

- Joining an invite is one tap on the row. Joining an available event is also one tap: the app requests the invite and confirms it in the same action.
- Cancelling asks for confirmation only when it costs money (after `chosen_send_date_time` or `late_deadline_date_time`).
- All preferences live on one searchable screen and save as you change them. Typeform branches that don't apply, such as LA neighborhoods for Austin members, are hidden.
- Every event detail ends with an "All fields" tree of the raw API payload.

## API

The app talks to `https://ios.api.222.place` (FastAPI) with `Authorization: Token <token>`.

| Endpoint | Use |
| --- | --- |
| `GET get_members_upcoming_events`, `get_members_current_events`, `get_members_past_events` | Events with RSVP, timeline, fees, groups, photos |
| `GET get_request_new_event_metadata` | Requestable events |
| `GET get_all_questionnaires` | Onboarding and pre-experience questions with answers and branch logic |
| `GET person_connections` | People you've met, with compatibility |
| `GET get_subscription?include_payments=false` | Subscription plan |
| `POST request_new_event` `{requested_event_id, origin}` | Request an invite |
| `POST update_attend_option?event_id=` `{attend_option_id}` | Join (free options confirm immediately) |
| `POST reject_event_invite?event_id=` | Pass, or cancel when `decline_type` is `REJECT_EVENT_INVITE` |
| `POST bail?event_id=` | Cancel when `decline_type` is `BAIL`; a 400 `SHOULD_REPROMPT` means the terms changed |
| `POST submit_answers` `{answers: {question_id: value}}` | Save preference answers |

Not supported yet: paid options (the Stripe PaymentSheet stays in the official app), plus-ones, and submitting post-event feedback (`submit_follow_up` takes a free-form body whose shape is unknown until a follow-up is pending).
