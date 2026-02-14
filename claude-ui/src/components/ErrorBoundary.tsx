import { Component, type ReactNode, type ErrorInfo } from "react";

interface Props {
  name: string;
  children: ReactNode;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`ErrorBoundary [${this.props.name}]:`, error, info.componentStack);
  }

  reset = () => {
    this.setState({ error: null });
  };

  render() {
    if (this.state.error) {
      return (
        <div className="px-4 py-3 my-1 rounded bg-red-950/30 border border-red-900/40 text-sm">
          <p className="text-red-400">
            <span className="font-medium">{this.props.name}</span> crashed:{" "}
            {this.state.error.message}
          </p>
          <button
            onClick={this.reset}
            className="mt-1 text-xs text-red-400 hover:text-red-300 underline"
          >
            Retry
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
