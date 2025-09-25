defmodule Quant.Explorer.PythonHelpersTest do
  @moduledoc """
  Test for the PythonHelpers module to ensure it works correctly.
  """

  use ExUnit.Case, async: true

  import Quant.Explorer.PythonHelpers

  describe "PythonHelpers" do
    test "python_available?/0 returns a boolean" do
      result = python_available?()
      assert is_boolean(result)

      if result do
        IO.puts("\n✅ Python is available for testing")
      else
        IO.puts("\n⚠️  Python is not available for testing")
      end
    end
  end
end
