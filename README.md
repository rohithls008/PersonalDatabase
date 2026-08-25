# PersonalDatabase

One file: `index.html` (HTML, CSS, and JavaScript together). It connects to a [Supabase](https://supabase.com) project from the browser.

## Run

```bash
python3 -m http.server 5173
```

Open [http://localhost:5173](http://localhost:5173).

## Connect

1. In Supabase go to **Project Settings → API**.
2. Paste the **Project URL** and **anon public** key into the left panel.
3. Credentials stay in this browser (`localStorage`), not in the file.

Create at least one table, enable Row Level Security, and add a policy for the `anon` role.
