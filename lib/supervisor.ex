defmodule Supercollider.Supervisor do
  @moduledoc """
  Supercollider Supervisor, handles OSC connections to sclang server, node messages and Port communication
  """
  use Supervisor  

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], name: :supercollider_supervisor)
  end

  def start_link([config]) do
    Supervisor.start_link(__MODULE__, [config], name: :supercollider_supervisor)
  end

  @impl true
  def init([]) do
    children = [
      %{
        id: :supercollider_server,
        start: {Supercollider.Server, :start_link, [[]]},
        restart: :permanent
      },
      %{
        id: :supercollider_notifications,
        start: {Supercollider.Server.Notifications, :start_link, [[]]},
        restart: :transient
      }
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end

  def init([config]) do
    children = case config[:boot] do
      true -> [
          %{
            id: :sclang,
            start: {Supercollider.Server.SClang, :start_link, [config]},
          }
      ]
      _ -> []
    end

    children = children ++ [
      %{
        id: :supercollider_server,
        start: {Supercollider.Server, :start_link, [config]},
        restart: :permanent
      },
      %{
        id: :supercollider_notifications,
        start: {Supercollider.Server.Notifications, :start_link, [[]]},
        restart: :transient
      }      
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end
