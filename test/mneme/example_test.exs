defmodule Mneme.ExampleTest do
  use ExUnit.Case
  use Mneme

  defmodule MyStruct do
    defstruct field: nil, list: [], map: %{}
  end

  test "1" do
    s1 = %MyStruct{}

    auto_assert %MyStruct{} <- s1
  end

  test "2" do
    s2 = %MyStruct{field: 5}

    auto_assert %MyStruct{field: 5, list: [:foo, :baz]} <- Map.put(s2, :list, [:foo, :baz])
  end

  test "3" do
    s3 = %MyStruct{field: self()}

    auto_assert %MyStruct{field: pid} when is_pid(pid) <- s3
  end

  test "4" do
    me = self()
    s4 = %MyStruct{field: me}

    auto_assert %MyStruct{field: ^me} <- s4
  end
end