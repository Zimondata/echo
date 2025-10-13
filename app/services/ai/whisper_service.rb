require "tempfile"

module Ai
  class WhisperService
    class << self
      def transcribe(audio_data, language: "ru")
        return nil if audio_data.blank?

        # Create temporary file for audio
        tempfile = create_temp_file(audio_data)

        begin
          # Call OpenAI Whisper API
          response = client.audio.transcribe(
            parameters: {
              model: "whisper-1",
              file: File.open(tempfile.path, "rb"),
              language: language
            }
          )

          response.dig("text")
        rescue StandardError => e
          Rails.logger.error "Whisper transcription error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          nil
        ensure
          tempfile.close
          tempfile.unlink
        end
      end

      private

      def client
        @client ||= OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          log_errors: Rails.env.development?
        )
      end

      def create_temp_file(audio_data)
        tempfile = Tempfile.new(["audio", ".ogg"])
        tempfile.binmode
        tempfile.write(audio_data)
        tempfile.rewind
        tempfile
      end
    end
  end
end
