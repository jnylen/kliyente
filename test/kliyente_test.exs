defmodule KliyenteTest do
  use ExUnit.Case
  doctest Kliyente

  test "greets the world" do
    assert Kliyente.hello() == :world
  end
end
