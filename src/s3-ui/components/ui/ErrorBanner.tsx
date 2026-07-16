interface ErrorBannerProps {
  message: string
  onClose: () => void
}

export function ErrorBanner({ message, onClose }: ErrorBannerProps) {
  return (
    <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
      {message}
      <button className="ml-2 underline text-xs" onClick={onClose}>Fechar</button>
    </div>
  )
}
