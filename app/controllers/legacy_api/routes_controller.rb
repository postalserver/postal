module LegacyAPI
  class RoutesController < BaseController

    # POST /api/v1/routes/create
    def create
      server = @current_credential.server

      # Find the route by name and domain_id
      route = server.routes.find_by(name: route_params[:name], domain_id: route_params[:domain_id])

      if route
        render_error("RouteAlreadyExists", message: "Route already exists", status: :conflict)
      else
        # Initialize the route without _endpoint first
        route = server.routes.new(route_params.except(:_endpoint))

        # Set the _endpoint and endpoint_id
        if route_params[:_endpoint].present?
          route._endpoint = route_params[:_endpoint]
        else
          uuid = SecureRandom.uuid
          route._endpoint = "HTTPEndpoint##{uuid}"
        end

        if route.save
          render_success(route: route.attributes.merge(_endpoint: route._endpoint))
        else
          render_error("ValidationError", message: route.errors.full_messages.to_sentence, status: :unprocessable_entity)
        end
      end
    end

    # DELETE /api/v1/routes/delete
    def delete
      route_id = params[:id].to_i
      route = @current_credential.server.routes.find_by(id: route_id)

      if route
        if route.destroy
          render_success(message: "Route deleted successfully")
        else
          render_error("RouteNotDeleted", message: "Failed to delete route", status: :unprocessable_entity)
        end
      else
        render_success(message: "Route does not exist")
      end
    end

    private

    def route_params
      params.require(:route).permit(:name, :domain_id, :endpoint_id, :endpoint_type, :mode, :spam_mode, :_endpoint)
    end
  end
end
