import { Badge } from '@/components/ui/badge'

interface User {
  id: number
  username: string
  isAdmin: boolean
  createdAt: string
}

interface UserTableProps {
  users: User[]
}

export function UserTable({ users }: UserTableProps) {
  return (
    <div className="bg-surface rounded-xl border border-gray-100 overflow-hidden">
      <table className="w-full text-sm">
        <thead className="bg-gray-50 text-xs uppercase text-gray-500">
          <tr>
            <th className="px-4 py-3 text-left">Usuário</th>
            <th className="px-4 py-3 text-left">Tipo</th>
            <th className="px-4 py-3 text-left">Criado em</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-50">
          {users.map((user) => (
            <tr key={user.id} className="hover:bg-gray-50">
              <td className="px-4 py-3 font-medium">{user.username}</td>
              <td className="px-4 py-3">
                {user.isAdmin
                  ? <Badge className="bg-primary text-text-main">Admin</Badge>
                  : <Badge variant="outline">Usuário</Badge>}
              </td>
              <td className="px-4 py-3 text-gray-400">
                {new Date(user.createdAt).toLocaleDateString('pt-BR')}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
