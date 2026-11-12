# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Domain.Persisters.IndexRoutesByResource do
  @moduledoc false
  use Spark.Dsl.Transformer

  def transform(dsl) do
    routes_by_resource =
      dsl
      |> AshJsonApi.Domain.Info.routes()
      |> Enum.group_by(& &1.resource)

    {:ok,
     Spark.Dsl.Transformer.persist(dsl, :ash_json_api_routes_by_resource, routes_by_resource)}
  end
end
