# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Test.AshJsonApi.ResourceRouteTest do
  use ExUnit.Case, async: true

  defmodule Author do
    use Ash.Resource,
      domain: Test.AshJsonApi.ResourceRouteTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    json_api do
      type("author")
    end

    actions do
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
    end
  end

  defmodule Post do
    use Ash.Resource,
      domain: Test.AshJsonApi.ResourceRouteTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshJsonApi.Resource]

    json_api do
      type("post")
      hide_fields([:editor])

      routes do
        base("/own_posts")
        index(:read, primary?: true)
      end
    end

    actions do
      defaults([:read])
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to(:author, Author, public?: true)
      belongs_to(:editor, Author, public?: true)
    end
  end

  defmodule Domain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain]

    json_api do
      routes do
        base_route "/authors", Author do
          get(:read, primary?: true)
        end

        base_route "/posts", Post do
          get(:read, primary?: true)
          related(:editor, :read, primary?: true)
          related(:author, :read)
          related(:author, :read, route: "/:id/writer", primary?: true)
        end
      end
    end

    resources do
      resource(Author)
      resource(Post)
    end
  end

  defmodule OtherDomain do
    use Ash.Domain,
      otp_app: :ash_json_api,
      extensions: [AshJsonApi.Domain],
      validate_config_inclusion?: false

    json_api do
      routes do
        base_route "/other_posts", Post do
          get(:read, primary?: true)
        end
      end
    end

    resources do
      allow_unregistered?(true)
    end
  end

  describe "AshJsonApi.Resource.Info.routes/2" do
    test "lists each domain's routes for the resource in order, then the resource's own" do
      assert [
               "/posts/:id",
               "/posts/:id/editor",
               "/posts/:id/author",
               "/posts/:id/writer",
               "/own_posts"
             ] == route_paths(Post, [Domain])

      assert [
               "/other_posts/:id",
               "/posts/:id",
               "/posts/:id/editor",
               "/posts/:id/author",
               "/posts/:id/writer",
               "/own_posts"
             ] == route_paths(Post, [OtherDomain, Domain])
    end

    test "is empty for a domain without routes for the resource" do
      assert [] == route_paths(Author, [OtherDomain])
    end
  end

  describe "AshJsonApi.Resource.route/3" do
    test "finds the first route matching the criteria across domains" do
      assert %{route: "/posts/:id"} =
               AshJsonApi.Resource.route(Post, [Domain, OtherDomain], %{
                 type: :get,
                 primary?: true
               })

      assert %{route: "/other_posts/:id"} =
               AshJsonApi.Resource.route(Post, [OtherDomain, Domain], %{
                 type: :get,
                 primary?: true
               })
    end

    test "skips routes to hidden relationships" do
      assert %{route: "/posts/:id/writer"} =
               AshJsonApi.Resource.route(Post, [Domain], %{
                 relationship: :author,
                 primary?: true,
                 action_type: :get_related
               })

      assert nil ==
               AshJsonApi.Resource.route(Post, [Domain], %{
                 relationship: :editor,
                 primary?: true,
                 action_type: :get_related
               })
    end
  end

  defp route_paths(resource, domains) do
    resource
    |> AshJsonApi.Resource.Info.routes(domains)
    |> Enum.map(& &1.route)
  end
end
