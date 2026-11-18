# Read-only account audit with nl2sql

This integration branch extends the existing SQLite user-directory example from [mizchi/sqlc_gen_moonbit](https://github.com/mizchi/sqlc_gen_moonbit) at revision `8fa8213b1b4eb33325e5c5045d330daf11eade2d`. It uses the example's generated database functions to create Alice and Bob, update Alice's name and email, and delete Bob. The app writes those changes to a new SQLite file. A second run uses the public `young9682/nl2sql/planner` API to audit that file.

The audit question asks which accounts with IDs of at least 1 remain. This reproduction supplies a fixed structured model reply and needs no API key. nl2sql reads the live schema, validates and compiles the plan, and runs a read-only query with the integer `1` bound as a parameter. The single returned record is ID 1, Alice Smith, `alice.smith@example.com`. The verifier asserts the typed row and confirms that the SHA-256 of the database stays the same across the audit. [Recorded output](audit-result.json)

## Reproduce on Windows

Use PowerShell 7.4 or later, Git, a MoonBit toolchain that supports `moon.work`, MSVC and the Windows SDK. The tested MoonBit compiler was `v0.10.20+65efd5b93`. Supply a SQLite SDK directory containing `include/sqlite3.h`, `lib/sqlite3.lib`, and `bin/sqlite3.dll`. A Conda environment with SQLite exposes this layout under `Library`.

From the repository root on this integration branch, run:

```powershell
./examples/sqlite_native/verify-nl2sql.ps1 -SqliteSdk 'C:\path\to\environment\Library'
```

The verifier copies the checked-out example to a fresh temporary directory, resolves nl2sql at revision `ab67b851b5367bdc9bd312c207e7739f743b148d`, and checks the pinned `mizchi/sqlite@0.2.1` archive before migrating its legacy manifest for the newer toolchain. It prints the original write workflow, the JSON evidence and the location of the reproduced report.
