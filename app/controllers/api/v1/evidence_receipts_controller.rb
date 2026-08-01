class Api::V1::EvidenceReceiptsController < Api::V1::TrustedController
  before_action :find_run

  def create
    receipt = @run.evidence_receipts.create!(
      evidence_receipt_params.merge(creator_service_token: @service_token)
    )
    success_response(serialize_receipt(receipt), message: "Evidence recorded", status: :created)
  end

  private

  def find_run
    @run = current_user.agent_runs.find(params[:agent_run_id])
  end

  def evidence_receipt_params
    params.require(:evidence_receipt).permit(
      :receipt_type,
      :summary,
      :tool_name,
      :target_ref,
      :result_ref,
      :verification,
      :occurred_at,
      redacted_inputs: {},
      metadata: {}
    )
  end

  def serialize_receipt(receipt)
    {
      id: receipt.id,
      agent_run_id: receipt.agent_run_id,
      receipt_type: receipt.receipt_type,
      summary: receipt.summary,
      tool_name: receipt.tool_name,
      target_ref: receipt.target_ref,
      result_ref: receipt.result_ref,
      verification: receipt.verification,
      verified: receipt.verified,
      occurred_at: receipt.occurred_at
    }
  end
end
