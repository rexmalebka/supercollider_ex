defmodule SCSynth do
  defstruct [:id, :controls, :set, :get]
end

defmodule Supercollider.Synth do
  def new(synthdef_name) when is_bitstring(synthdef_name) do
    last =
      0..3000
      |> Enum.take_while(fn idx ->
        get(1000 + idx, 0) != {:error, :not_found}
      end)
      |> Enum.at(-1)

    last = last + 1001
    new(synthdef_name, last)
  end

  def new(synthdef_name, synth_id, control_args \\ %{}, [{action, target}] \\ [{:tail, 1}])
      when is_bitstring(synthdef_name) and
             is_integer(synth_id) and
             is_map(control_args) and
             action in [:tail, :head, :before, :after] do
    action = Enum.find_index([:head, :tail, :before, :after], fn x -> x == action end)

    args =
      control_args
      |> Enum.flat_map(fn
        {a, b} when is_atom(a) -> [to_string(a), b]
        {a, b} -> [a, b]
      end)

    Supercollider.Server.cast_send(["/s_new", synthdef_name, synth_id, action, target | args])

    %SCSynth{
      id: synth_id,
      controls: control_args,
      set: &Supercollider.Synth.set(synth_id, &1),
      get: &Supercollider.Synth.get(synth_id, &1)
    }
  end

  def set(synthid, control_args) do
    controls = Enum.into(control_args, %{})
    Supercollider.Node.set(synthid, controls)
  end

  def get(synth_id, control)
      when is_integer(synth_id) and (is_integer(control) or is_bitstring(control)) do
    msg = %OSC.Message{
      address: "/s_get",
      arguments: [synth_id, control]
    }

    case Supercollider.Server.call_send(msg) do
      {:ok, %{contents: [%{address: "/n_set", arguments: [^synth_id | args]}]}} -> args
      {:ok, %{contents: [%{address: "/fail"}]}} -> {:error, :not_found}
      error -> error
    end
  end
end
