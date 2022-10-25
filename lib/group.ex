defmodule SCGroupQuery do
  @type t() :: %__MODULE__{
    id: integer(),
    nodes: [SCSynthQuery.t()| SCGroupQuery.t()]
  }
  defstruct [:id, :nodes]
end

defmodule SCSynthQuery do
  @type t() :: %__MODULE__{
    id: integer(),
    synthdef: String.t(),
    controls: Map.t()
  }

  defstruct [:id, :synthdef, :controls]
end

defmodule Supercollider.Group do
  @moduledoc """
  Implementation of Group commands (retrieved from https://doc.sccode.org/Reference/Server-Command-Reference.html#Group%20Commands)
  """

  defp parseNode([node_id, synth_flag, synthdef_name, num_controls | rest_data], nodes)
       when <<synth_flag>> == <<-1>> do
    {controls_data, rest} = Enum.split(rest_data, 2 * num_controls)
    controls = controls_data |> Enum.chunk_every(2) |> Map.new(fn [k, v] -> {k, v} end)

    parseNode(
      rest,
      nodes ++
        [
          %SCSynthQuery{
            id: node_id,
            synthdef: synthdef_name,
            controls: controls
          }
        ]
    )
  end

  defp parseNode([group_id, num_childs | rest], nodes) do
    parseNode(
      rest,
      nodes ++
        [
          %SCGroupQuery{
            id: group_id,
            nodes: num_childs
          }
        ]
    )
  end

  defp parseNode([], nodes) do
    {tree, _} = group_tree(nodes)
    tree
  end

  defp group_nodes([synth | rest_data], nodes, acc)
       when synth.__struct__ == SCSynthQuery and length(nodes) != acc do
    group_nodes(rest_data, nodes ++ [synth], acc)
  end

  defp group_nodes([group | rest_data], nodes, acc)
       when group.__struct__ == SCGroupQuery and length(nodes) != acc do
    {group, rest} = group_tree([group | rest_data])
    group_nodes(rest, nodes ++ [group], acc)
  end

  defp group_nodes(rest, nodes, acc) when length(nodes) == acc do
    {nodes, rest}
  end

  defp group_tree([group | rest_data]) when group.__struct__ == SCGroupQuery do
    {nodes, rest} = group_nodes(rest_data, [], group.nodes)
    group = %{group | nodes: nodes}
    {group, rest}
  end

  defp parse_tree([1 | node_data]) do
    parseNode(node_data, [])
  end

  @doc "query tree structure for certain group, with synth controls info."
  @spec query_tree(group_id::integer()) :: {:error, :not_found} | {:error, :timeout} | SCGroupQuery.t()
  def query_tree(group_id \\ 0) when is_integer(group_id) do
    case Supercollider.Server.call_send(["/g_queryTree", group_id, 1]) do
      {:ok, %{contents: [%{address: "/fail"}]}} -> {:error, :not_found}
      {:ok, %{contents: [%{address: "/g_queryTree.reply", arguments: args}]}} -> parse_tree(args)
      error -> error
    end
  end

  @type action_atom() :: :head | :tail | :before | :after | :replace

  @doc """
  Create a new group.

  allowed actions are the following:

  | **action atom** | **description**                                                                          |
  |-----------------|------------------------------------------------------------------------------------------|
  | `:head`         | add the new group to the head of the group specified by `target`.                        |
  | `:tail`         | add the new group to the tail of the group specified by `target`.                        |
  | `:before`       | add the new group just before the node specified by `target`.                            |
  | `:after`        | add the new group just after the node specified by the add target I.                     |
  | `:replace`      | the new node replaces the node specified by `target`. The target node is freed.          |

  """
  @spec new(group_id::integer(), [{action::action_atom(), target::integer()}]):: :ok
  def new(group_id, [{action, target}] \\ [{:tail, 0}])
      when is_integer(group_id) and
             action in [:tail, :head, :before, :after, :replace] do
    action = Enum.find_index([:head, :tail, :before, :after, :replace], fn x -> x == action end)

    msg = %OSC.Message{
      address: "/g_new",
      arguments: [group_id, action, target]
    }

    Supercollider.Server.cast_send(msg)
  end

  @doc "Delete all nodes in a group." 
  @spec free(group_id::integer()) :: :ok
  def free(group_id) when is_integer(group_id) do
    msg = %OSC.Message{
      address: "/g_freeAll",
      arguments: [group_id]
    }

    Supercollider.Server.cast_send(msg)
  end

  @doc "Free all synths in this group and all its sub-groups."
  @spec deep_free(group_id::integer()) :: :ok
  def deep_free(group_id) when is_integer(group_id) do
    msg = %OSC.Message{
      address: "/g_deepFree",
      arguments: [group_id]
    }

    Supercollider.Server.cast_send(msg)
  end
end
