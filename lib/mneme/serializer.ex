defmodule Mneme.Serializer do
  @moduledoc false

  @doc """
  Converts `value` into an AST that could be used to match that value.

  The second `context` argument is a map containing information about
  the context in which the expressions will be evaluated. It contains:

    * `:binding` - a keyword list of variables/values present in the
      calling environment

  Must return `{match_ast, guard_ast, notes}`, where `guard_ast` is an
  additional guard expression that will run in scope of variables bound
  in `match_ast`, and `notes` is a list of strings that may be displayed
  to the user to explain the generated pattern.
  """
  @callback to_pattern(value :: any(), context :: map()) ::
              {Macro.t(), Macro.t() | nil, [binary()]}

  @doc """
  Default implementation of `c:to_pattern`.
  """
  def to_pattern(value, context)

  def to_pattern(value, _context)
      when is_atom(value) or is_integer(value) or is_float(value) do
    {value, nil, []}
  end

  def to_pattern(string, _context) when is_binary(string) do
    if String.contains?(string, "\n") do
      {{:__block__, [delimiter: ~S(""")], [format_for_heredoc(string)]}, nil, []}
    else
      {string, nil, []}
    end
  end

  def to_pattern(list, context) when is_list(list) do
    enum_to_pattern(list, context)
  end

  def to_pattern({a, b}, context) do
    case {Mneme.Serializer.to_pattern(a, context), Mneme.Serializer.to_pattern(b, context)} do
      {{expr1, nil, notes1}, {expr2, nil, notes2}} ->
        {{expr1, expr2}, nil, notes1 ++ notes2}

      {{expr1, guard, notes1}, {expr2, nil, notes2}} ->
        {{expr1, expr2}, guard, notes1 ++ notes2}

      {{expr1, nil, notes1}, {expr2, guard, notes2}} ->
        {{expr1, expr2}, guard, notes1 ++ notes2}

      {{expr1, guard1, notes1}, {expr2, guard2, notes2}} ->
        {{expr1, expr2}, {:and, [], [guard1, guard2]}, notes1 ++ notes2}
    end
  end

  def to_pattern(tuple, context) when is_tuple(tuple) do
    values = Tuple.to_list(tuple)
    {value_matches, guard, notes} = enum_to_pattern(values, context)
    {{:{}, [], value_matches}, guard, notes}
  end

  for {var_name, guard} <- [ref: :is_reference, pid: :is_pid, port: :is_port] do
    def to_pattern(value, context) when unquote(guard)(value) do
      case fetch_pinned(value, context[:binding]) do
        {:ok, pin} -> {pin, nil, []}
        :error -> guard(unquote(var_name), unquote(guard))
      end
    end
  end

  for module <- [DateTime, NaiveDateTime, Date, Time] do
    def to_pattern(%unquote(module){} = value, context) do
      case fetch_pinned(value, context[:binding]) do
        {:ok, pin} -> {pin, nil, []}
        :error -> {value |> inspect() |> Code.string_to_quoted!(), nil, []}
      end
    end
  end

  def to_pattern(%URI{} = uri, context) do
    struct_to_pattern(URI, Map.delete(uri, :authority), context, [])
  end

  def to_pattern(%struct{} = value, context) do
    if ecto_schema?(struct) do
      {value, notes} = prepare_ecto_struct(value)
      struct_to_pattern(struct, value, context, notes)
    else
      struct_to_pattern(struct, value, context, [])
    end
  end

  def to_pattern(%{} = map, context) do
    {tuples, guard, notes} = enum_to_pattern(map, context)
    {{:%{}, [], tuples}, guard, notes}
  end

  defp struct_to_pattern(struct, map, context, notes) do
    {aliased, _} =
      context
      |> Map.get(:aliases, [])
      |> List.keyfind(struct, 1, {struct, struct})

    aliases = aliased |> Module.split() |> Enum.map(&String.to_atom/1)
    empty = struct.__struct__()

    {map_expr, guard, inner_notes} =
      map
      |> Map.filter(fn {k, v} -> v != Map.get(empty, k) end)
      |> Mneme.Serializer.to_pattern(context)

    {{:%, [], [{:__aliases__, [], aliases}, map_expr]}, guard, notes ++ inner_notes}
  end

  defp format_for_heredoc(string) when is_binary(string) do
    if String.ends_with?(string, "\n") do
      string
    else
      string <> "\\\n"
    end
  end

  defp fetch_pinned(value, binding) do
    case List.keyfind(binding || [], value, 1) do
      {name, ^value} -> {:ok, {:^, [], [{name, [], nil}]}}
      _ -> :error
    end
  end

  defp enum_to_pattern(values, context) do
    {list, {guard, notes}} =
      Enum.map_reduce(values, {nil, []}, fn value, {guard, notes} ->
        case {guard, Mneme.Serializer.to_pattern(value, context)} do
          {nil, {expr, guard, ns}} -> {expr, {guard, notes ++ ns}}
          {guard, {expr, nil, ns}} -> {expr, {guard, notes ++ ns}}
          {guard1, {expr, guard2, ns}} -> {expr, {{:and, [], [guard1, guard2]}, notes ++ ns}}
        end
      end)

    {list, guard, notes}
  end

  defp guard(name, guard) do
    var = {name, [], nil}
    {var, {guard, [], [var]}, []}
  end

  defp ecto_schema?(module) do
    function_exported?(module, :__schema__, 1)
  end

  defp prepare_ecto_struct(%schema{} = struct) do
    autogenerated_fields = get_autogenerated_fields(schema)
    primary_keys = schema.__schema__(:primary_key)

    drop_fields =
      Enum.concat([
        [:__meta__],
        schema.__schema__(:primary_key),
        get_autogenerated_fields(schema)
      ])

    {Map.drop(struct, drop_fields), ecto_struct_notes(primary_keys, autogenerated_fields)}
  end

  defp ecto_struct_notes(pk, []) do
    ["Excluding Ecto primary key `#{inspect(pk)}` and meta field `:__meta__`."]
  end

  defp ecto_struct_notes(pk, auto_fields) do
    [
      "Excluding Ecto primary key `#{inspect(pk)}`, auto generated fields `#{inspect(auto_fields)}`, and meta field `:__meta__`."
    ]
  end

  # The Schema.__schema__(:autogenerate_fields) call was introduced after
  # Ecto v3.9.4, so we rely on an undocumented call using :autogenerate
  # for versions prior to that.
  ecto_supports_autogenerate_fields? =
    with {:ok, charlist} <- :application.get_key(:ecto, :vsn),
         {:ok, version} <- Version.parse(List.to_string(charlist)) do
      Version.compare(version, "3.9.4") == :gt
    else
      _ -> false
    end

  if ecto_supports_autogenerate_fields? do
    def get_autogenerated_fields(schema) do
      schema.__schema__(:autogenerate_fields)
    end
  else
    def get_autogenerated_fields(schema) do
      :autogenerate
      |> schema.__schema__()
      |> Enum.flat_map(&elem(&1, 0))
    end
  end
end
