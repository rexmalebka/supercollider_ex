# Supercollider

Elixir implementation of Supercollider client.

## Installation

1. add `supercollider` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:supercollider, "~> 0.1.0"}
  ]
end
```

2. get deps

```bash
$ mix deps.get 
```

3. compile

```bash
$ mix compile
```

4. gen docs with:


```bash
$ mix docs
```

## Usage


**running Supercollider process**
 
first, make sure Supercollider Server it's running:

1. Run sclang process or scide.

```bash
$ sclang -u 57110 # set 57110 port
```

2. run this lines, to boot the server.

```supercollider
s.options.maxLogins = 8; // set this to allow register for notifications.
s.boot;
```
- In case you want Elixir to manage the process:

```elixir
 Supercollider.Server.boot()
```

**Start Elixir implementation**


1. you can use `Supercollider.Server.start_link/1` into children supervisor:

```elixir
children = [
  %{
    id: :supercollider_server,
    start: {Supercollider.Server, :start_link, []]}
  }
]
```

2. alternatively you can run:

```elixir
Supercollider.Server.start_link([])
```

3. you could also let Elixir spawn Supercollider process: 

```elixir
Supercollider.Server.boot()
```

- or in a supervisor:

```elixir
children = [
  %{
    id: :supercollider_server,
    start: {Supercollider.Server, :boot, []]}
  }
]
```



## Examples


```elixir
iex(1)> Supercollider.Server.start_link([])
{:ok, #PID<0.239.0>}
iex(2)> Supercollider.Server.version()
%SCVersion{
  name: "scsynth",
  major: 3,
  minor: 12,
  patch_name: ".2",
  git_branch: "not_a_git_checkout",
  hash: "na"
}
iex(3)> Supercollider.Server.status()
%SCStatus{
  ugens: 12,
  synths: 1,
  groups: 9,
  synthdefs: 110,
  avg_cpu: 0.9217846393585205,
  peak_cpu: 0.9244298934936523,
  nominal_samplerate: 48000.0,
  actual_samplerate: 48000.12624296966
}
iex(4)> Supercollider.Group.query_tree()
%SCGroupQuery{
  id: 0,
  nodes: [
    %SCGroupQuery{id: 469762049, nodes: []},
    %SCGroupQuery{id: 402653185, nodes: []},
    %SCGroupQuery{id: 335544321, nodes: []},
    %SCGroupQuery{id: 268435457, nodes: []},
    %SCGroupQuery{id: 201326593, nodes: []},
    %SCGroupQuery{id: 134217729, nodes: []},
    %SCGroupQuery{id: 67108865, nodes: []},
    %SCGroupQuery{id: 1, nodes: []},
    %SCSynthQuery{id: 1000, synthdef: "safeClip_2", controls: %{"limit" => 1.0}}
  ]
}
iex(5)> Supercollider.Server.quit()
:ok

```


## TODO

- create documentation
- publish on hex.pmm
- `Supercollider.Server.boot()` callback
- test inside a supervisor
- make tests
- check lacking Server commands
- generate Synthdef with elixir
- make an proof of concept video

## References

[Server Command Reference](https://doc.sccode.org/Reference/Server-Command-Reference.html)

[Synth definition file format](http://doc.sccode.org/Reference/Synth-Definition-File-Format.html)

