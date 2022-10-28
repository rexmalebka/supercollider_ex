defmodule SC.Config do
  @moduledoc """
  Supercollider Configuration.
  """

  defstruct [
    address: "127.0.0.1",
    port: 57_110,
    client_port: 0
  ]
end

defmodule SC.Version do
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

defmodule SC.Status do
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
    address = Application.get_env(:supercollider, :address)
    port = Application.get_env(:supercollider, :port)
    client_port = Application.get_env(:supercollider, :client_port)

    GenServer.start_link(__MODULE__, {address, port, client_port}, name: :supercollider_server)
  end
  
  def start_link([config]) when is_list(config) do
    address = case is_bitstring(config[:address]) do
      true -> config[:address]
      false -> Application.get_env(:supercollider, :address, "127.0.0.1")
    end

    port = case is_integer(config[:port]) do
      true -> config[:port]
      false -> Application.get_env(:supercollider, :port, 57_110)
    end

    client_port = case is_integer(config[:client_port]) do
      true -> config[:client_port]
      false -> Application.get_env(:supercollider, :client_port, 0)
    end


    GenServer.start_link(__MODULE__, {address, port, client_port}, name: :supercollider_server)
  end


  @impl true
  def init({
    address,
    port,
    client_port
  }) when is_bitstring(address) and is_integer(port) and is_integer(client_port) do

    {:ok, socket} = :gen_udp.open(client_port, [:binary, active: false])
    {:ok, address} = :inet_parse.address(String.to_charlist(address))

    state = %{
      socket: socket,
      config: %SC.Config{
        address: address,
        port: port,
        client_port: client_port
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:send, osc_data}, _From, state) do
    {:ok, osc_packet} = OSC.encode(osc_data)

    :gen_udp.send(
      state.socket,
      state.config.address,
      state.config.port,
      osc_packet
    )

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
  def handle_call({:get, :config}, _From, state) do
    {:reply, state.config, state}
  end

  @impl true
  def handle_call(msg, _From, state) do
    IO.puts("call: #{inspect(msg)}")
    {:reply, msg, state}
  end

  @impl true
  def handle_cast({:send, osc_data}, state) do
    {:ok, osc_packet} = OSC.encode(osc_data)

    :gen_udp.send(
      state.socket,
      state.config.address,
      state.config.port,
      osc_packet
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, _addr, _port, data}, state)
      when socket == state.notification_socket do
    _msg = OSC.decode(data)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
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

end


defmodule Supercollider do
  @moduledoc """
  Supercollider API.
  """

  @doc "boots genserver with a spawned port connection to sclang"
  def boot do
    Supercollider.Supervisor.start_link([boot: true])
  end

  @doc "retrieve Supercollider version."
  @spec version() :: SC.Version.t()
  def version do
    response =
      case Supercollider.Server.call_send(["/version"]) do
        {:ok, osc_packet} ->
          args = Enum.at(osc_packet.contents, 0).arguments

          %SC.Version{
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
      case Supercollider.Server.call_send(["/quit"]) do
        {:ok, _osc_packet} -> :ok
        error -> error
      end

    response
  end

  @doc "retrieve Supercollider initial config."
  @spec config() :: SC.Config.t()
  def config do
    GenServer.call(:supercollider_server, {:get, :config})
  end

  @doc "retrieve Supercollider Status."
  @spec status() :: SC.Status.t()
  def status do
    response =
      case Supercollider.Server.call_send(["/status"]) do
        {:ok, osc_packet} ->
          args = Enum.at(osc_packet.contents, 0).arguments

          %SC.Status{
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

end
