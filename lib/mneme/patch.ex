defmodule Mneme.Patch do
  @moduledoc false

  alias Mneme.Format
  alias Mneme.Serialize
  alias Sourceror.Zipper

  defmodule SuiteResult do
    @moduledoc false
    defstruct asts: %{}, patches: %{}
  end

  def apply_changes!(%SuiteResult{patches: patches} = state) do
    Enum.each(patches, &patch_file!/1)
    %{state | patches: %{}}
  end

  def handle_assertion(state, {type, _expr, actual, meta}) do
    file = meta[:file]
    line = meta[:line]

    {ast, state} = file_data(state, file)

    {_, patch} =
      ast
      |> Zipper.zip()
      |> Zipper.traverse(nil, fn
        {{:auto_assert, assert_meta, [_]} = assert, _} = zipper, nil ->
          if assert_meta[:line] == line do
            {zipper, assertion_patch(type, meta, actual, assert)}
          else
            {zipper, nil}
          end

        zipper, patch ->
          {zipper, patch}
      end)

    if patch do
      {{:ok, patch.expr}, update_in(state.patches[file], &[patch | &1])}
    else
      {:error, state}
    end
  end

  defp file_data(%{asts: asts} = state, file) do
    case {asts, file} do
      {%{^file => ast}, _} ->
        {ast, state}

      {_asts, file} ->
        ast = file |> File.read!() |> Sourceror.parse_string!()

        state =
          state
          |> Map.update!(:asts, &Map.put(&1, file, ast))
          |> Map.update!(:patches, &Map.put(&1, file, []))

        {ast, state}
    end
  end

  defp assertion_patch(
         type,
         meta,
         actual,
         {:auto_assert, _, [inner]} = assert
       ) do
    format_opts = Rewrite.DotFormatter.opts()
    original = {:auto_assert, [], [inner]} |> Sourceror.to_string(format_opts)
    expr = update_match(type, inner, Serialize.to_match_expressions(actual, meta))

    replacement =
      {:auto_assert, [], [expr]}
      |> Sourceror.to_string(format_opts)

    if accept_change?(type, meta, original, replacement) do
      %{expr: expr, change: replacement, range: Sourceror.get_range(assert)}
    end
  end

  defp update_match(:new, value, expected) do
    match_expr(expected, value, [])
  end

  defp update_match(:replace, {:<-, meta, [_old, value]}, expected) do
    match_expr(expected, value, meta)
  end

  defp match_expr({match_expr, nil}, value, meta) do
    {:<-, meta, [match_expr, value]}
  end

  defp match_expr({match_expr, conditions}, value, meta) do
    {:<-, meta, [{:when, [], [match_expr, conditions]}, value]}
  end

  defp accept_change?(type, meta, original, replacement) do
    operation =
      case type do
        :new -> "New"
        :replace -> "Update"
      end

    message = """
    \n[Mneme] #{operation} assertion - #{meta[:file]}:#{meta[:line]}

    #{Format.prefix_lines(original, "- ")}
    #{Format.prefix_lines(replacement, "+ ")}
    """

    IO.puts(message)
    prompt_action("Accept change? (y/n) ")
  end

  defp prompt_action(prompt) do
    case IO.gets(prompt) do
      response when is_binary(response) ->
        response
        |> String.trim()
        |> String.downcase()
        |> case do
          "y" ->
            true

          "n" ->
            false

          other ->
            IO.puts("unknown response: #{other}")
            prompt_action(prompt)
        end

      :eof ->
        prompt_action(prompt)
    end
  end

  defp patch_file!({_file, []}), do: :ok

  defp patch_file!({file, patches}) do
    source = File.read!(file)
    patched = Sourceror.patch_string(source, patches)
    File.write!(file, patched)
  end
end
