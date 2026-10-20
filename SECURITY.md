# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Email **poplex.help@outlook.com** with the subject line `Security: <short summary>` and include:

- what the problem is and where it is (file, Edge Function, or screen);
- how to reproduce it;
- the impact you think it has.

Please give a reasonable amount of time to fix it before disclosing it publicly.
This is a small, individually maintained project, so replies are best-effort.

## What this repository does and does not contain

- It contains **no real backend address, API key or user data.** The Supabase
  project URL and key in `AIEnglishApp/Services/SupabaseConfig.swift` are
  placeholders you replace with your own.
- The app never holds an AI provider key; those only exist in Edge Function
  environment variables, which are never committed.

If you find a real credential anywhere in this repository or its history, please
report it using the address above.
