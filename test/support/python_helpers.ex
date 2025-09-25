defmodule Quant.Explorer.PythonHelpers do
  @moduledoc """
  Helper functions for Python integration and validation tests.
  """

  import Pythonx

  def python_available? do
    result = ~PY"""
    import pandas
    import numpy
    "OK"
    """

    # Extract the string value from the Pythonx object
    result_str = result |> inspect() |> String.contains?("OK")
    result_str
  rescue
    _ -> false
  end
end
