defmodule Supercollider.Server.Notifications do
  @moduledoc """
  This module handles Supercollider server notifications.
  """
  use GenServer

  @doc false
  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: :supercollider_notifications)
  end

  @impl true
  def init([]) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    id = :rand.uniform(500 + 2000)

    # start receiving notifications
    msg = %OSC.Message{
      address: "/notify",
      arguments: [1, id]
    }

    {:ok, osc_packet} = OSC.encode(msg)
    
    :gen_udp.send(socket, {127, 0, 0, 1}, 57_110, osc_packet)


    {:ok, {_, _, res}}  = :gen_udp.recv(socket, 0, 3_000)
    IO.puts("#{inspect( OSC.decode(res))}")

    case OSC.decode(res) do
      {:ok, %{contents: [%{address: "/fail"}]}} -> :ignore
      {:ok, %{contents: [%{address: "/done", arguments: ["/notify", num_clients, max_clients]}]}} -> 
        :inet.setopts(socket, active: true)
        state = %{
          socket: socket,
          id: id,
          max_clients: max_clients,
          clients: num_clients,
          listeners: []
        }

        {:ok, state}
      _error -> :ignore
    end
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(msg, _from, state) do
    {:reply, msg, state}
  end

  @impl true
  def handle_cast({:add, listener}, state) do
    state = %{state | listeners: state.listeners ++ [listener]}
    {:noreply, state}
  end

  @impl true
  def handle_cast({:remove, listener}, state) do
    state = %{state | listeners: Enum.reject(
      state.listeners, fn x -> x == listener end)}
    {:noreply, state}
  end

  @impl true
  def handle_cast(msg, state) do
    IO.puts("#{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    {:ok, %{contents: [%{address: cmd, arguments: args}]}} = OSC.decode(data)
    IO.puts("#{inspect(cmd)}, #{inspect(args)}")

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    {:noreply, state}
  end

  @doc "add a process listener to receive notifications messages."
  @spec add_listener(listener::atom | pid()) :: :ok
  def add_listener(port) when is_pid(port) or is_atom(port) do
    GenServer.cast(:supercollider_notifications, {:add, port})
  end

  @doc "remove process listener to receive notifications messages."
  @spec remove_listener(listener::atom | pid()) :: :ok
  def remove_listener(listener) when is_pid(listener) or is_atom(listener) do
    GenServer.cast(:supercollider_notifications, {:remove, listener})
  end

end
