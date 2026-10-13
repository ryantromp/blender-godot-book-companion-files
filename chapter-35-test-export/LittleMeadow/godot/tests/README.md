# Tests of Little Meadow

This folder holds 15 test files (`test_*.gd`), a `data` folder and one small runner, `run_tests.gd`. Together the
test files hold 295 tests and 7,899 checks. Nothing else is needed: no add-on, no second tool, no window.

## Run all tests

Import the project once (a fresh clone has no `.godot` folder), then run the runner. Both commands start in the
project folder, the one that holds `project.godot`:

```
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

`godot` is the Godot 4.7.2 editor program (the full path of the file works too). The run takes 3 to 5 minutes. The
last lines of the output are:

```
LM_TESTS passed=295 failed=0 errors=0
```

and the exit code is 0. A failed test prints a line that starts with `FAIL`, with the file, the test name and what
was expected. The exit code is then 1.

The log also holds a few `ERROR` and `WARNING` lines that the tests provoke on purpose (a broken settings file,
a sound that does not exist), and leak lines at the end ("resources still in use at exit"). They are not failures.
Only the `LM_TESTS` line and the exit code count.

## Run a part

Add `-- --filter=text` after the command. The text must be part of `file::test_name`:

```
godot --headless --path . --script res://tests/run_tests.gd -- --filter=test_ch28
godot --headless --path . --script res://tests/run_tests.gd -- --filter=test_ch28.gd::test_a_click
```

## How a test looks

A test file is a script with methods that start with `test_`. Each gets one helper, `t`, with the checks
(`t.ok`, `t.eq`, `t.ne`, `t.approx`, `t.vec_approx`, `t.not_null`), waiting (`await t.frames(n)`,
`await t.physics_frames(n)`, `await t.secs(s)`), and simulated input (`t.press_action`, `t.tap_action`, `t.key`,
`t.mouse_move`, `t.click`). `run_tests.gd` shows how they are made. The optional `before_all(t)`,
`before_each(t)` and `after_each(t)` run around the tests.

## Notes

- Some tests write `tests/data/sample_slot.json`. If `git status` shows it as changed after a run, restore it with
  `git checkout tests/data/sample_slot.json`.
- A few tests write a `saves_test` folder and a `settings_test.cfg` file into the game's user folder and delete them
  again. To keep your own game files away from the tests entirely (Linux), point `XDG_DATA_HOME` and
  `XDG_CONFIG_HOME` at an empty folder for the run.
- At the tags `ch28` to `ch35` the test `test_a_click_walks_to_the_chicken_and_feeds_it` is the older version, which
  can fail now and then when a wandering hen stands in front of the egg. A second run passes. On `main` the animals
  stand still during that test.
- `run_tests.gd` first appears on `main`. At the tags `ch21` to `ch35` the folder has no runner. Copy it from `main`:
  `git show main:tests/run_tests.gd > tests/run_tests.gd`.
