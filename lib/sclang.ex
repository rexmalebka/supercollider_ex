defmodule Supercollider.Server.SClang do
  @moduledoc """
  Server implementation of sclang process.
  """
  use GenServer

  def start_link(config) do
    address = Application.get_env(:supercollider, :address)
    port = Application.get_env(:supercollider, :port)

    GenServer.start_link(__MODULE__, {address, port}, name: :supercollider_server)
  end

  @impl true
  def init({address, port}) when is_bitstring(address) and is_integer(port) do
    state = %{
      port: Port.open({:spawn, "sclang "}, [:binary])
    }
    {:ok, state}
  end

  @impl true
  def handle_call(msg, _from, state) do
    {:reply, msg, state}
  end

  @impl true
  def handle_cast(msg, state) do
    IO.puts("cast #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    IO.puts("info #{inspect(msg)}")
    {:noreply, state}
  end
end
