import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'

interface User {
  id: number
  username: string
  isAdmin: boolean
  mustChangePassword: boolean
  createdAt: string
}

interface UserTableProps {
  users: User[]
  currentUserId: number
  onDelete: (userId: number) => void
  onResetPassword: (userId: number) => void
}

export function UserTable({ users, currentUserId, onDelete, onResetPassword }: UserTableProps) {
  return (
    <div className="bg-surface rounded-xl border border-gray-100 overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-gray-50 text-xs uppercase text-gray-500">
          <tr>
            <th className="px-4 py-3 text-left">Usuário</th>
            <th className="px-4 py-3 text-left">Tipo</th>
            <th className="px-4 py-3 text-left">Criado em</th>
            <th className="px-4 py-3 text-left">Ações</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-50">
          {users.map((user) => (
            <tr key={user.id} className="hover:bg-gray-50">
              <td className="px-4 py-3 font-medium">
                <span>{user.username}</span>
                {user.mustChangePassword && (
                  <Badge className="ml-2 bg-red-100 text-red-700 border-red-200 text-xs rounded-full px-2">
                    Não acessou
                  </Badge>
                )}
              </td>
              <td className="px-4 py-3">
                {user.isAdmin
                  ? <Badge className="bg-primary text-text-main">Admin</Badge>
                  : <Badge variant="outline">Usuário</Badge>}
              </td>
              <td className="px-4 py-3 text-gray-400">
                {new Date(user.createdAt).toLocaleDateString('pt-BR')}
              </td>
              <td className="px-4 py-3">
                <div className="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    className="text-xs"
                    onClick={() => onResetPassword(user.id)}
                    aria-label="Resetar senha"
                  >
                    Resetar senha
                  </Button>
                  {user.id !== currentUserId && (
                    <Button
                      size="sm"
                      variant="ghost"
                      className="text-xs text-delete-text bg-delete-bg hover:bg-red-200"
                      onClick={() => onDelete(user.id)}
                      aria-label="Deletar"
                    >
                      Deletar
                    </Button>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
