  $ source $TESTDIR/scaffold

Usage:

  $ judge --help
  Test runner for Judge.
  
    jpm_tree/bin/judge FILE[:LINE:COL]
  
  If no targets are given on the command line, Judge will look for tests in the
  current working directory.
  
  Targets can be file names, directory names, or FILE:LINE:COL to run a test at a
  specific location (which is mostly useful for editor tooling).
  
  === flags ===
  
    [--help]                   : Print this help text and exit
    [-a], [--accept]           : overwrite source files with .tested files
    [--not-name-exact NAME]... : skip tests whose name is exactly this prefix
    [--name-exact NAME]...     : only run tests with this exact name
    [--not-name PREFIX]...     : skip tests whose name starts with this prefix
    [--name PREFIX]...         : only run tests whose name starts with the given
                                 prefix

  $ use test.janet <<EOF
  > (use judge)
  > (deftest "first"
  >   (test 1 1))
  > (deftest "second"
  >   (test 1 1))
  > EOF

Runs everything by default:

  $ judge test.janet
  ! running test: first
  ! running test: second
  ! 2 passed 0 failed 0 skipped 0 unreachable

Name matches prefix:

  $ judge test.janet --name fir
  ! running test: first
  ! 1 passed 0 failed 1 skipped 0 unreachable

Name exact does not match prefix:

  $ judge test.janet --name-exact fir
  ! 0 passed 0 failed 2 skipped 0 unreachable
  [1]

At:

  $ judge test.janet:2:1
  ! running test: first
  ! 1 passed 0 failed 1 skipped 0 unreachable

At should work for any position in between start and end:

  $ judge test.janet:2:20
  ! running test: first
  ! 1 passed 0 failed 1 skipped 0 unreachable

TODO: this is a weird bug
At should work for any column position even if it exceeds the length of the file:

  $ judge test.janet:1:1000
  ! 0 passed 0 failed 2 skipped 0 unreachable
  [1]

You can exclude tests:

  $ judge test.janet --not-name first
  ! running test: second
  ! 1 passed 0 failed 1 skipped 0 unreachable

Accepting tests overwrites the file:

  $ use test.janet <<EOF
  > (use judge)
  > (deftest "test"
  >   (test 1))
  > EOF

  $ judge test.janet -a
  ! running test: test
  ! <red>- (test 1)</>
  ! <grn>+ (test 1 1)</>
  ! 0 passed 1 failed 0 skipped 0 unreachable
  [1]
  $ cat test.janet
  (use judge)
  (deftest "test"
    (test 1 1))

Does not traverse hidden files or folders:

  $ rm *.janet
  $ mkdir .hidden

  $ cat >.hidden/hello.janet <<EOF
  > (use judge)
  > (print "hello")
  > (test 1 1)
  > EOF

  $ cat >.foo.janet <<EOF
  > (use judge)
  > (print "hidden file")
  > (test 1 1)
  > EOF

  $ judge
  ! 0 passed 0 failed 0 skipped 0 unreachable
  [1]

  $ judge test.janet
  ! error: could not read "test.janet"
  [1]

Will run hidden files or folders by explicit request:

  $ judge .foo.janet
  hidden file
  ! running test: .foo.janet:3:1
  ! 1 passed 0 failed 0 skipped 0 unreachable

  $ judge .hidden
  hello
  ! running test: .hidden/hello.janet:3:1
  ! 1 passed 0 failed 0 skipped 0 unreachable

  $ judge .hidden/hello.janet
  hello
  ! running test: .hidden/hello.janet:3:1
  ! 1 passed 0 failed 0 skipped 0 unreachable

Accepting refuses to run if file has been modified:

  $ use test.janet <<EOF
  > (use judge)
  > (deftest "test"
  >   (test 1))
  > (os/sleep 0.1)
  > EOF

  $ judge test.janet -a &

  $ sleep 0.01

  $ echo "modified" > test.janet
  $ sleep 0.1
  ! running test: test
  ! <red>- (test 1)</>
  ! <grn>+ (test 1 1)</>
  ! <red>test.janet changed since test runner began; refusing to overwrite</>
  ! 0 passed 1 failed 0 skipped 0 unreachable

Can be used as a jpm task:

  $ use test.janet <<EOF
  > (use judge)
  > (test 1 1)
  > EOF

  $ cat >project.janet <<EOF
  > (task "test" [] (shell "jpm_tree/bin/judge"))
  > EOF

  $ jpm test 2>&1 | sanitize
  running test: test.janet:2:1
  1 passed 0 failed 0 skipped 0 unreachable
