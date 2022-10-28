defmodule ServerTest do
  use ExUnit.Case, async: true
  doctest Supercollider.Server 
  
  test "Supercollider process registration and default server_config" do
    {:ok, port} = Supercollider.Server.start_link([])
    server_config = Supercollider.config

    # default server_configuration 
    assert server_config.address == {127, 0, 0, 1} 
    assert server_config.port == 57_110 

    # check registered name it's :supercollider_Server
    assert :supercollider_server in Process.registered() 
    assert Process.whereis(:supercollider_server) == port

  end

  test "test changing port" do

    {:ok, _port} = Supercollider.Server.start_link([[port: 57_123]])
    server_config = Supercollider.config
    
    assert server_config.port == 57_123
  
  end

  test "test error timeout" do
    {:ok, _port} = Supercollider.Server.start_link([[port: 57_777]])

    res = Supercollider.version()
    assert res == {:error, :timeout}
  end

  test "test SC struct types for server" do
    {:ok, _pid} = Supercollider.Server.start_link([])

    version = Supercollider.version
    status = Supercollider.status
    config = Supercollider.config

    assert version.__struct__  ==  SC.Version
    assert status.__struct__ == SC.Status
    assert config.__struct__ == SC.Config
  end

  test "test Supervisor" do

    {:ok, pid} = Supercollider.Supervisor.start_link([])

    assert Supercollider.status != {:error, :timeout}
  end

end

