# frozen_string_literal: true

class TaheController < ApiController
  post '/q/:__table_name' do
    tbl_name = params[:__table_name]
    h_cond, h_sort = parse_params(_params)
    r = M[tbl_name.to_sym].query(h_cond, {sort: h_sort}).to_a
    r.to_resp
  end

  post '/test/t' do
    '123'
  end
end
