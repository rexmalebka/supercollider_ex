defmodule Supercollider.Synthdef do
  def load(path) do
    path = Path.absname(path)

    res =
      case File.stat(path) do
        {:ok, stat} when stat.type == :regular ->
          Supercollider.Server.call_send(["/d_load", path])

        {:ok, stat} when stat.type == :directory ->
          Supercollider.Server.call_send(["/d_loadDir", path])

        {:error, error} ->
          {:error, error}
      end

    case res do
      {:ok, %{contents: [%{address: "/done"}]}} -> {:ok, :done}
      error -> error
    end
  end

  def free(name) when is_bitstring(name) do
    Supercollider.Server.cast_send(["/d_free", name])
  end
end
