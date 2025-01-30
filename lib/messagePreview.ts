export class MessagePreviewClient {
  private ws: WebSocket
  private messageCallback: (preview: string) => void
  private errorCallback: (error: string) => void
  private completeCallback: () => void

  constructor(
    url: string,
    onMessage: (preview: string) => void,
    onError: (error: string) => void,
    onComplete: () => void
  ) {
    this.ws = new WebSocket(url)
    this.messageCallback = onMessage
    this.errorCallback = onError
    this.completeCallback = onComplete

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data)
      
      if (data.error) {
        this.errorCallback(data.error)
      } else if (data.type === 'preview') {
        this.messageCallback(data.content)
      } else if (data.type === 'complete') {
        this.completeCallback()
      }
    }

    this.ws.onerror = (error) => {
      this.errorCallback('WebSocket error: ' + error)
    }
  }

  requestPreview(params: {
    message_text: string
    customer_id: string
    style?: string
    context_type?: string
  }) {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(params))
    } else {
      this.errorCallback('WebSocket not connected')
    }
  }

  close() {
    this.ws.close()
  }
}