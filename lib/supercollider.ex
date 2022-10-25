defmodule SCVersion do
  @moduledoc """
  Version info (retrieved from https://doc.sccode.org/Reference/Server-Command-Reference.html#/version)
  """

  @typedoc "Superccollider version"
  @type t :: %__MODULE__{
          name: name(),
          major: major(),
          minor: minor(),
          patch_name: patch_name(),
          git_branch: git_branch(),
          hash: hash()
        }

  @typedoc "Program name. May be \"scsynth\" or \"supernova\"."
  @type name() :: bitstring()

  @typedoc "Major version number. Equivalent to sclang's Main.scVersionMajor."
  @type major() :: integer()

  @typedoc "Minor version number. Equivalent to sclang's Main.scVersionMinor."
  @type minor() :: integer()

  @typedoc "Patch version name. Equivalent to the sclang code \".\" ++ Main.scVersionPatch ++ Main.scVersionTweak."
  @type patch_name() :: bitstring()

  @typedoc "Git branch name."
  @type git_branch() :: bitstring()

  @typedoc "First seven hex digits of the commit hash."
  @type hash() :: bitstring()

  defstruct [:name, :major, :minor, :patch_name, :git_branch, :hash]
end

defmodule SCStatus do
  @moduledoc """
  Status info (retrieved from https://doc.sccode.org/Reference/Server-Command-Reference.html#/status)
  """

  @typedoc "Supercollider status."
  @type t :: %__MODULE__{
          ugens: ugen(),
          synths: synth(),
          synthdefs: synthdefs(),
          groups: groups(),
          avg_cpu: avg_cpu(),
          peak_cpu: peak_cpu(),
          nominal_samplerate: nominal_samplerate(),
          actual_samplerate: actual_samplerate()
        }

  @typedoc "number of unit generators."
  @type ugen :: integer()

  @typedoc "number of synths."
  @type synth :: integer()

  @typedoc "number of loaded synth definitions."
  @type synthdefs :: integer()

  @typedoc "number of groups."
  @type groups :: integer()

  @typedoc "average percent CPU usage for signal processing"
  @type avg_cpu :: float()

  @typedoc "peak percent CPU usage for signal processing"
  @type peak_cpu :: float()

  @typedoc "nominal sample rate"
  @type nominal_samplerate :: float()

  @typedoc "actual sample rate"
  @type actual_samplerate :: float()

  defstruct [
    :ugens,
    :synths,
    :groups,
    :synthdefs,
    :avg_cpu,
    :peak_cpu,
    :nominal_samplerate,
    :actual_samplerate
  ]
end

defmodule Supercollider.Server do
  @moduledoc """
  Supercollider UDP GenServer implementation, uses as default port 57110 to communicate with Supercollider Server.

  Implements in  the background Basic OSC Server commands https://doc.sccode.org/Reference/Server-Command-Reference.html
  """
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: :supercollider_server)
  end

  @doc false
  def start_link([:sclang]) do
    GenServer.start_link(__MODULE__, [], name: :supercollider_server)
  end

  @doc "boots genserver with a spawned port connection to sclang"
  def boot do
    start_link([:sclang])
  end

  @impl true
  def init([]) do
    {:ok, socket} = :gen_udp.open(57200, [:binary, active: false])
    {:ok, notification_socket} = :gen_udp.open(57300, [:binary, active: true])

    id = :rand.uniform(500 + 2000)

    state = %{
      socket: socket,
      notification_socket: notification_socket,
      id: id
    }

    # start receiving notifications
    msg = %OSC.Message{
      address: "/notify",
      arguments: [1, id]
    }

    {:ok, osc_packet} = OSC.encode(msg)
    :gen_udp.send(notification_socket, {127, 0, 0, 1}, 57110, osc_packet)

    # sclang: Port.open({:spawn, "sclang -u 57110"})
    # Port.command
    {:ok, state}
  end

  @impl true
  def handle_call({:send, osc_data}, _From, state) do
    {:ok, osc_packet} = OSC.encode(osc_data)

    :gen_udp.send(state.socket, {127, 0, 0, 1}, 57110, osc_packet)

    msg =
      case :gen_udp.recv(state.socket, 0, 3_000) do
        {:error, :timeout} -> {:error, :timeout}
        {:ok, {_, _, raw_msg}} -> OSC.decode(raw_msg)
      end

    {:reply, msg, state}
  end

  @impl true
  def handle_call({:get, :id}, _From, state) do
    {:reply, state.id, state}
  end

  @impl true
  def handle_call(msg, _From, state) do
    IO.puts("call: #{inspect(msg)}")
    {:reply, msg, state}
  end

  @impl true
  def handle_cast({:send, osc_data}, state) do
    {:ok, osc_packet} = OSC.encode(osc_data)

    :gen_udp.send(state.socket, {127, 0, 0, 1}, 57110, osc_packet)

    {:noreply, state}
  end

  @impl true
  def handle_cast(_Msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, _addr, _port, data}, state)
      when socket == state.notification_socket do
    _msg = OSC.decode(data)
    {:noreply, state}
  end

  @impl true
  def handle_info(_Msg, state) do
    {:noreply, state}
  end

  @doc "sends an OSC message to Server, waiting for a response."
  @spec call_send(OSC.Message.t()) :: OSC.Parser.t()
  def call_send(msg) do
    GenServer.call(:supercollider_server, {:send, msg})
  end

  @doc "sends an OSC message to Server, without waiting for a response."
  @spec cast_send(OSC.Message.t()) :: :ok
  def cast_send(msg) do
    GenServer.cast(:supercollider_server, {:send, msg})
  end

  @doc "logs commands into sclang stdout, for debugging purposes."
  @spec dump(integer()) :: :ok
  def dump(dump_code \\ 0)
      when is_integer(dump_code) and dump_code >= 0 and dump_code <= 3 do
    cast_send(["/dumpOSC", dump_code])
  end

  @doc "retrieve Supercollider Status."
  @spec status() :: SCStatus.t()
  def status do
    response =
      case call_send(["/status"]) do
        {:ok, osc_packet} ->
          args = Enum.at(osc_packet.contents, 0).arguments

          %SCStatus{
            ugens: Enum.at(args, 1),
            synths: Enum.at(args, 2),
            groups: Enum.at(args, 3),
            synthdefs: Enum.at(args, 4),
            avg_cpu: Enum.at(args, 5),
            peak_cpu: Enum.at(args, 6),
            nominal_samplerate: Enum.at(args, 7),
            actual_samplerate: Enum.at(args, 8)
          }

        error ->
          error
      end

    response
  end

  @doc "retrieve Supercollider version."
  @spec version() :: SCVersion.t()
  def version do
    response =
      case call_send(["/version"]) do
        {:ok, osc_packet} ->
          args = Enum.at(osc_packet.contents, 0).arguments

          %SCVersion{
            name: Enum.at(args, 0),
            major: Enum.at(args, 1),
            minor: Enum.at(args, 2),
            patch_name: Enum.at(args, 3),
            git_branch: Enum.at(args, 4),
            hash: Enum.at(args, 5)
          }

        error ->
          error
      end

    response
  end

  @doc "quits Supercollider Server."
  @spec quit() :: :ok | {:error, :timeout}
  def quit do
    response =
      case call_send(["/quit"]) do
        {:ok, _osc_packet} -> :ok
        error -> error
      end

    response
  end
end
