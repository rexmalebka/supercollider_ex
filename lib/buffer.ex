defmodule SCBufferQuery do
  @type t() :: %__MODULE__{
    id: integer(),
    frames: integer(),
    channels: integer(),
    samplerate: float()
  }
  defstruct [:id, :frames, :channels, :samplerate]
end

defmodule SCBuffer do
  @type t() :: %__MODULE__{
    id: integer(),
    path: bitstring(),
    query: query(),
    get_frame: get_frame(),
    free: free()
  }

  @typedoc "query callback"
  @type query() :: (() ->  SCBufferQuery.t() | {:error, :timeout}  )

  @typedoc "get frame callback "
  @type get_frame() :: ((frame::integer()) ->  float() | {:error, :not_found} | {:error, :not_found} )

  @typedoc "free callback"
  @type free() :: (() -> :ok)

  defstruct [:id, :path, :query, :get_frame, :free]
end

defmodule Supercollider.Buffer do
  @moduledoc """
  Implementation of Buffer commands (retrieved from https://doc.sccode.org/Reference/Server-Command-Reference.html#Buffer%20Commands)
  """

  @doc "load a buffer from a path, check for consecutive free buffer id"
  @spec load(path::bitstring()) :: {:error, :not_implemented}
  def load(path) do
    last =
      0..4000
      |> Enum.take_while(fn idx ->
        get_frame(idx) != {:error, :not_found}
      end)
      |> Enum.at(-1)

    buffer_id = last + 1

    load(path, buffer_id)
  end

  @doc "load a buffer from a path."
  @spec load(path::bitstring(), buffer_id::integer(), start::integer(), total_framse::integer()) :: {:error, :not_implemented} | SCBuffer.t()
  def load(path, buffer_id, start \\ 0, total_frames \\ -1)
  when is_bitstring(path) and is_integer(buffer_id) and is_integer(start) and start >= 0 and
  is_integer(total_frames) do
    abspath = :filename.absname(path)

    case File.exists?(abspath) do
      true ->
        msg = %OSC.Message{
          address: "/b_allocRead",
          arguments: [buffer_id, abspath, start, total_frames]
        }

        case Supercollider.Server.call_send(msg) do
          {:ok, %{contents: [%{address: "/done", arguments: ["/b_allocRead", ^buffer_id]}]}} ->
            %SCBuffer{
              id: buffer_id,
              path: abspath,
              query: fn -> Supercollider.Buffer.query(buffer_id) end,
              get_frame: &Supercollider.Buffer.get_frame(buffer_id, &1),
              free: fn -> Supercollider.Buffer.free(buffer_id) end
            }

          {:ok, %{contents: [%{address: "/fail"}]}} ->
            {:error, :not_implemented}

          error ->
            error
        end

      false ->
        {:error, :not_found}
    end
  end

  @doc "get buffer frame "
  @spec get_frame(buffer_id::integer(), frame::integer()) :: float() | {:error, :not_found} | {:error, :not_found}
  def get_frame(buffer_id, frame \\ 0) when is_integer(buffer_id) and is_integer(frame) do
    msg = %OSC.Message{
      address: "/b_get",
      arguments: [buffer_id, frame]
    }

    case Supercollider.Server.call_send(msg) do
      {:ok, %{contents: [%{address: "/b_set", arguments: [^buffer_id, ^frame, value]}]}} -> value
      {:ok, %{contents: [%{address: "/fail"}]}} -> {:error, :not_found}
      error -> error
    end
  end

  @doc "query buffer info"
  @spec query(buffer_id::integer()) :: SCBufferQuery.t() | {:error, :timeout}
  def query(buffer_id) when is_integer(buffer_id) do
    msg = %OSC.Message{
      address: "/b_query",
      arguments: [buffer_id]
    }

    case Supercollider.Server.call_send(msg) do
      {:ok,
        %{contents: [%{address: "/b_info", arguments: [^buffer_id, frames, channels, samplerate]}]}} ->
        %SCBufferQuery{
          id: buffer_id,
          frames: frames,
          channels: channels,
          samplerate: samplerate
        }

      error ->
        error
    end
  end

  @doc "Free a buffer."
  @spec free(buffer_id::integer()) :: :ok
  def free(buffer_id) when is_integer(buffer_id) do
    msg = %OSC.Message{
      address: "/b_free",
      arguments: [buffer_id]
    }

    case Supercollider.Server.call_send(msg) do
      {:ok, %{contents: [%{address: "/done", arguments: ["/b_free", ^buffer_id]}]}} -> :ok
      error -> error
    end
  end
end
