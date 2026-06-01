export const metadata = {
  title: 'Política de Privacidade — Betel App',
}

export default function PrivacyPolicyPage() {
  return (
    <main className="max-w-3xl mx-auto px-6 py-12 text-gray-800">
      <h1 className="text-3xl font-bold mb-2">Política de Privacidade</h1>
      <p className="text-sm text-gray-500 mb-8">Última atualização: 1º de junho de 2026</p>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">1. Introdução</h2>
        <p>
          A <strong>Sociedade de Amparo Social Betel (Betel App)</strong> desenvolveu o aplicativo
          <strong> Betel App</strong> como um serviço de uso interno dos membros da comunidade Betel.
          Esta página informa sobre nossa política referente à coleta, uso e divulgação de informações
          pessoais quando você utiliza nosso serviço.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">2. Informações Coletadas</h2>
        <p className="mb-3">Coletamos os seguintes tipos de informação:</p>
        <ul className="list-disc pl-6 space-y-2">
          <li>
            <strong>Dados de conta:</strong> nome e senha fornecidos no cadastro, gerenciados
            pelos administradores da Betel App.
          </li>
          <li>
            <strong>Dados de uso:</strong> informações sobre como você acessa e utiliza o
            aplicativo (aulas acessadas, progresso de reprodução).
          </li>
          <li>
            <strong>Dados do dispositivo:</strong> informações técnicas como sistema operacional
            e versão do aplicativo, usadas exclusivamente para fins de suporte.
          </li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">3. Uso das Informações</h2>
        <p className="mb-3">Utilizamos as informações coletadas para:</p>
        <ul className="list-disc pl-6 space-y-2">
          <li>Fornecer e manter o acesso ao conteúdo educacional da comunidade.</li>
          <li>Gerenciar sua conta e autenticar seu acesso.</li>
          <li>Identificar e corrigir problemas técnicos no aplicativo.</li>
          <li>Notificar sobre mudanças em nosso serviço.</li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">4. Compartilhamento de Dados</h2>
        <p>
          Não vendemos, trocamos ou transferimos suas informações pessoais para terceiros.
          Os dados são utilizados exclusivamente para a operação interna do aplicativo Betel App.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">5. Segurança</h2>
        <p>
          Utilizamos medidas técnicas adequadas para proteger suas informações. Senhas são
          armazenadas com hash criptográfico e nunca são expostas em texto simples.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">6. Retenção de Dados</h2>
        <p>
          Mantemos seus dados enquanto sua conta estiver ativa. Caso sua conta seja removida
          pelos administradores, os dados associados são excluídos do sistema.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">7. Seus Direitos</h2>
        <p>
          Em conformidade com a Lei Geral de Proteção de Dados (LGPD — Lei nº 13.709/2018),
          você tem direito a acessar, corrigir ou solicitar a exclusão dos seus dados pessoais.
          Para exercer esses direitos, entre em contato com o administrador responsável da
          sua comunidade Betel.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-3">8. Contato</h2>
        <p>
          Em caso de dúvidas sobre esta política de privacidade, entre em contato com a
          administração da Betel App pelo e-mail ou pelos canais internos da comunidade.
        </p>
      </section>

      <p className="text-sm text-gray-400 mt-12 border-t pt-4">
        Betel App &mdash; Todos os direitos reservados.
      </p>
    </main>
  )
}
