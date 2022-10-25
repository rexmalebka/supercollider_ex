defmodule SCNodeQuery do
  @type t() :: %__MODULE__{
    id: integer(),
    parent: parent(),
    previous: previous(),
    next: next(),
    type: :group | :synth,
    group: [head: head(), tail: tail()] | nil
  }
  
  defstruct [:id, :parent, :previous, :next, :type, group: nil ]

  @typedoc "the node's parent group ID"
  @type parent() :: integer()

  @typedoc "previous node ID, -1 if no previous node."
  @type previous() :: integer()

  @typedoc "next node ID, -1 if no next node."
  @type next() :: integer()

  @typedoc "the ID of the head node, -1 if there is no head node."
  @type head() :: integer()

  @typedoc "the ID of the tail node, -1 if there is no head node."
  @type tail() :: integer()

end

defmodule Supercollider.Node do
  @doc "Set a node's control value, If the node is a group, then it sets the controls of every node in the group."
  @spec set(node_id::integer(), control_args::Map.t()) :: :ok
  def set(node_id, control_args) when is_integer(node_id) and is_map(control_args) do
    args = control_args |> Enum.flat_map(fn {a, b} -> [a, b] end)

    Supercollider.Server.cast_send(%OSC.Message{
      address: "/n_set",
      arguments: [node_id | args]
    })
  end

  @doc "Get info about a node."
  @spec query(node_id::integer()) :: SCNodeQuery.t()
  def query(node_id) when is_integer(node_id) do
    msg = %OSC.Message{
      address: "/n_query",
      arguments: [node_id]
    }

    Supercollider.Server.call_send(msg)
  end
end
